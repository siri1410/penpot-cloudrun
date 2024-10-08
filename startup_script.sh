#!/bin/bash

# Create directories
mkdir -p frontend/build backend .github/workflows

# Frontend Dockerfile
cat << EOF > frontend/Dockerfile
FROM nginx:alpine

COPY build /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF

# Backend Dockerfile
cat << EOF > backend/Dockerfile
FROM node:16-alpine

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

RUN npm run build

EXPOSE 8080

CMD ["node", "dist/index.js"]
EOF

# Docker Compose file
cat << EOF > docker-compose.yaml
version: "3.8"
services:
  penpot-postgres:
    image: postgres:13
    environment:
      - POSTGRES_DB=penpot
      - POSTGRES_USER=penpot
      - POSTGRES_PASSWORD=penpot
    volumes:
      - penpot-postgres-data:/var/lib/postgresql/data
    restart: always

  penpot-redis:
    image: redis:6
    restart: always

  penpot-backend:
    build: ./backend
    environment:
      - REDIS_HOST=penpot-redis
      - POSTGRES_HOST=penpot-postgres
      - POSTGRES_DB=penpot
      - POSTGRES_USER=penpot
      - POSTGRES_PASSWORD=penpot
      # Uncomment and adjust the following if you're using a custom domain
      # - PENPOT_HOST=your-domain.com
      # - PENPOT_PROTOCOL=https 
    ports:
      - "8080:8080" # Expose the backend port
    depends_on:
      - penpot-postgres
      - penpot-redis
    restart: always

  penpot-frontend:
    build: ./frontend
    environment:
      - REACT_APP_API_URL=http://penpot-backend:8080 
      # Use the backend container name and exposed port
    ports:
      - "9001:80"
    depends_on:
      - penpot-backend
    restart: always

volumes:
  penpot-postgres-data:
EOF

# GitHub Actions workflow
cat << EOF > .github/workflows/cloudrun.yaml
name: Deploy to Cloud Run

on:
  push:
    branches:
      - main  # Trigger on pushes to the main branch

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v0
        with:
          project_id: \${{ secrets.GCP_PROJECT_ID }}
          service_account_key: \${{ secrets.GCP_SA_KEY }}

      - name: Configure Docker authentication
        run: gcloud auth configure-docker

      - name: Build and push Docker images
        run: |
          docker build -t gcr.io/\${{ secrets.GCP_PROJECT_ID }}/penpot-frontend ./frontend
          docker push gcr.io/\${{ secrets.GCP_PROJECT_ID }}/penpot-frontend
          docker build -t gcr.io/\${{ secrets.GCP_PROJECT_ID }}/penpot-backend ./backend
          docker push gcr.io/\${{ secrets.GCP_PROJECT_ID }}/penpot-backend

      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy penpot-frontend \
            --image gcr.io/\${{ secrets.GCP_PROJECT_ID }}/penpot-frontend \
            --platform managed \
            --region us-central1 \
            --allow-unauthenticated \
            --port 80
          gcloud run deploy penpot-backend \
            --image gcr.io/\${{ secrets.GCP_PROJECT_ID }}/penpot-backend \
            --platform managed \
            --region us-central1 \
            --allow-unauthenticated \
            --port 8080 \
            --set-env-vars GOOGLE_CLIENT_ID=\${{ secrets.GOOGLE_CLIENT_ID }},GOOGLE_CLIENT_SECRET=\${{ secrets.GOOGLE_CLIENT_SECRET }},GOOGLE_CALLBACK_URL=\${{ secrets.GOOGLE_CALLBACK_URL }}
          
          # Deploy other services (database, Redis) as needed

      - name: Display service URLs
        run: |
          gcloud run services list --platform managed --region us-central1
EOF

echo "Files created successfully!"