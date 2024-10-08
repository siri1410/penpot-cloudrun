#!/bin/bash

# ... (previous code to create files)

# Get GitHub username
read -p "Enter your GitHub username: " github_username

# Get GitHub personal access token (PAT)
read -p "Enter your GitHub personal access token (or press Enter to open browser for authorization): " github_pat

# If no PAT is provided, open the GitHub authorization page in the browser
if [[ -z "$github_pat" ]]; then
  echo "Opening GitHub in your browser for authorization..."
  open "https://github.com/settings/tokens/new?scopes=repo&description=Penpot%20Cloud%20Run%20Deployment"
  read -p "Enter the generated personal access token: " github_pat
fi

# Create a new GitHub repository
echo "Creating a new GitHub repository..."
curl -H "Authorization: token $github_pat" https://api.github.com/user/repos -d '{"name":"penpot-cloudrun"}'

# Initialize a Git repository
git init

# Add all files to the staging area
git add .

# Commit the changes with a message
git commit -m "Initial commit with Penpot, Cloud Run, and Firebase setup"

# Add the GitHub repository as a remote
git remote add origin https://github.com/$github_username/penpot-cloudrun.git

# Push the changes to the main branch
git push -u origin main

echo "Project checked in to GitHub successfully!"