# Setup Instructions

## Initial GitHub Repository Setup

### 1. Create GitHub Repository

1. Go to [GitHub](https://github.com/new)
2. Create a new repository named `cloud-platform-cicd-automation`
3. Don't initialize with README (we already have one)
4. Click "Create repository"

### 2. Link Local Repository to GitHub

Run these commands in your terminal:

```powershell
# Add the remote repository
git remote add origin https://github.com/nikhilgummadavelli8/cloud-platform-cicd-automation.git

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: Project foundation and documentation"

# Push to GitHub (use main as default branch)
git branch -M main
git push -u origin main
```

### 3. Enable Workflow Permissions

To allow the daily auto-commit workflow to work:

1. Go to your repository on GitHub
2. Click **Settings** → **Actions** → **General**
3. Scroll to **Workflow permissions**
4. Select **Read and write permissions**
5. Check **Allow GitHub Actions to create and approve pull requests** (optional)
6. Click **Save**

### 4. Verify Daily Auto-Commit Workflow

The workflow will automatically:
- Run every day at 11:59 PM UTC
- Check for any uncommitted changes
- Commit and push changes if found
- Skip if no changes detected

You can also trigger it manually:
1. Go to **Actions** tab in your GitHub repository
2. Select **Daily Auto Commit** workflow
3. Click **Run workflow**

## Alternative: Manual Commits

If you prefer to commit manually each day, use:

```powershell
git add .
git commit -m "Update: $(Get-Date -Format 'yyyy-MM-dd')"
git push
```

## Notes

- The automated workflow uses GitHub Actions bot to commit
- Adjust the cron schedule in `.github/workflows/daily-commit.yml` to change the time
- Current schedule: `59 23 * * *` (11:59 PM UTC daily)
- To change to your timezone, calculate the UTC offset and adjust accordingly
