# Bitbucket Pipelines Setup Guide

This guide walks you through setting up Bitbucket Pipelines for automated testing and deployment.

## Step 1: Create Bitbucket Repository

1. Go to your Bitbucket workspace
2. Click **Create** > **Repository**
3. Name your repository (e.g., `wordpress-site`)
4. Choose **Private** or **Public**
5. Click **Create repository**

## Step 2: Push Your Code to Bitbucket

```bash
# Initialize Git (if not already done)
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial WordPress Docker setup with CI/CD"

# Add Bitbucket as remote
git remote add origin git@bitbucket.org:YOUR_WORKSPACE/YOUR_REPO.git

# Push to Bitbucket
git push -u origin main
```

## Step 3: Enable Bitbucket Pipelines

1. Go to your repository in Bitbucket
2. Click **Pipelines** in the left sidebar
3. Click **Enable Pipelines**
4. The `bitbucket-pipelines.yml` file will be detected automatically

## Step 4: Configure Repository Variables

Go to **Repository Settings** > **Pipelines** > **Repository variables** and add:

### Required Variables

| Variable Name | Value | Secured |
|--------------|-------|---------|
| `SSH_PRIVATE_KEY` | Your SSH private key content | ✓ Yes |
| `PROD_SERVER_HOST` | `production-server.com` | No |
| `PROD_SSH_USER` | `username` | No |
| `PROD_PATH` | `/var/www/html` | No |

### How to Get SSH Private Key

```bash
# Generate a new SSH key (if you don't have one)
ssh-keygen -t rsa -b 4096 -C "bitbucket-pipeline"

# Copy the private key content
cat ~/.ssh/id_rsa

# Copy everything from -----BEGIN RSA PRIVATE KEY----- to -----END RSA PRIVATE KEY-----
```

**Important:**
- Mark `SSH_PRIVATE_KEY` as **Secured** (checkbox)
- Add the corresponding **public key** (`~/.ssh/id_rsa.pub`) to your production server's `~/.ssh/authorized_keys`

## Step 5: Add SSH Known Hosts

1. Go to **Repository Settings** > **Pipelines** > **SSH keys**
2. Click **Add known host**
3. Enter your production server hostname
4. Click **Fetch** to retrieve the host key
5. Click **Add host**

Alternatively, add manually:

```bash
# Get your server's SSH fingerprint
ssh-keyscan production-server.com

# Copy the output and paste it in the "Known hosts" section
```

## Step 6: Configure Production Server

### Add Pipeline SSH Key to Server

```bash
# On your local machine, copy the public key
cat ~/.ssh/id_rsa.pub

# SSH to your production server
ssh user@production-server.com

# Add the public key to authorized_keys
echo "ssh-rsa AAAA... bitbucket-pipeline" >> ~/.ssh/authorized_keys

# Set correct permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

### Install Required Software on Production

```bash
# SSH to production server
ssh user@production-server.com

# Install WP-CLI (optional, for cache flushing)
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp

# Verify installation
wp --info
```

## Step 7: Test the Pipeline

### Test on Feature Branch

```bash
# Create a test branch
git checkout -b test/pipeline

# Make a small change
echo "# Test" >> README.md

# Commit and push
git add README.md
git commit -m "Test pipeline"
git push origin test/pipeline
```

Go to **Pipelines** in Bitbucket to watch the build:
- Install Dependencies ✓
- Code Quality Checks ✓
- Security Scan ✓
- WordPress Standards ✓
- PHPUnit Tests ✓

### Test Deployment (Main Branch)

**Warning:** This will deploy to production!

```bash
# Switch to main branch
git checkout main

# Merge your test branch
git merge test/pipeline

# Push to trigger deployment
git push origin main
```

Watch in Bitbucket Pipelines:
- All tests run
- Deployment step executes
- Files sync to production
- Cache is cleared

## Step 8: Create Pull Request Workflow

```bash
# Create feature branch
git checkout -b feature/my-feature

# Make changes
# ... edit files ...

# Commit changes
git add .
git commit -m "Add new feature"

# Push to Bitbucket
git push origin feature/my-feature
```

In Bitbucket:
1. Click **Create pull request**
2. Select source: `feature/my-feature` → destination: `main`
3. Add description and reviewers
4. Pipeline runs automatically on PR
5. Reviewers can see test results
6. Merge when tests pass and approved
7. Main branch pipeline runs and deploys

## Pipeline Workflows

### Default Branch (Not Main)
```
┌─────────────────────┐
│ Install Dependencies│
└──────────┬──────────┘
           │
           ├─────────────────┐
           │                 │
    ┌──────▼─────┐   ┌──────▼────────┐
    │Code Quality│   │Security Scan  │
    └──────┬─────┘   └───────┬───────┘
           │                 │
           └────────┬────────┘
                    │
            ┌───────▼──────┐
            │PHPUnit Tests │
            └──────────────┘
```

### Main Branch
```
┌─────────────────────┐
│ Install Dependencies│
└──────────┬──────────┘
           │
           ├─────────────────┐
           │                 │
    ┌──────▼─────┐   ┌──────▼────────┐
    │Code Quality│   │Security Scan  │
    └──────┬─────┘   └───────┬───────┘
           │                 │
           └────────┬────────┘
                    │
            ┌───────▼──────┐
            │PHPUnit Tests │
            └──────┬───────┘
                   │
         ┌─────────▼──────────┐
         │Deploy to Production│
         └────────────────────┘
```

## Troubleshooting

### Pipeline Fails: SSH Connection

**Error:** `Permission denied (publickey)`

**Solution:**
1. Verify SSH_PRIVATE_KEY is set correctly in repository variables
2. Ensure public key is in production server's `~/.ssh/authorized_keys`
3. Check SSH known hosts are configured

### Pipeline Fails: Tests

**Error:** Tests failing in pipeline but passing locally

**Solution:**
1. Check test database credentials in `tests/bootstrap.php`
2. Ensure tests don't depend on local environment
3. Review pipeline logs for specific test failures

### Pipeline Fails: Deployment

**Error:** `rsync: command not found` or permission errors

**Solution:**
1. Ensure rsync is installed on production server: `sudo apt-get install rsync`
2. Verify PROD_PATH exists and user has write permissions
3. Check file permissions: `ls -la /var/www/html`

### Pipeline Times Out

**Error:** Pipeline exceeds time limit

**Solution:**
1. Reduce number of files being scanned by PHPCS
2. Use caches for Composer dependencies
3. Consider splitting into separate pipelines

## Custom Pipeline Triggers

### Manual Deployment Only

From Bitbucket UI:
1. Go to **Pipelines**
2. Click **Run pipeline**
3. Select **Custom: deploy-only**
4. Click **Run**

### Disable Auto-Deployment

Edit `bitbucket-pipelines.yml` and comment out the deployment step:

```yaml
branches:
  main:
    - step: *install-dependencies
    - parallel:
      - step: *code-quality
      - step: *security-scan
      - step: *wordpress-standards
    - step: *phpunit-tests
    # - step: *deploy-production  # Commented out for manual deployment only
```

## Best Practices

1. **Never commit sensitive data** - Use repository variables
2. **Test on feature branches** before merging to main
3. **Use pull requests** for code review
4. **Monitor pipeline runs** in Bitbucket
5. **Keep backups** - Pipeline creates backups automatically
6. **Review deployment logs** after each production deployment
7. **Use staging branch** for pre-production testing (configure separately)

## Security Notes

- SSH private key is stored encrypted in Bitbucket
- Mark sensitive variables as "Secured"
- Never log sensitive data in pipeline scripts
- Rotate SSH keys periodically
- Use separate keys for different environments
- Review pipeline permissions regularly

## Next Steps

1. ✓ Set up Bitbucket repository
2. ✓ Configure repository variables
3. ✓ Add SSH keys
4. ✓ Test pipeline on feature branch
5. ✓ Test deployment to production
6. Consider setting up a staging environment
7. Add custom tests for your theme/plugin
8. Configure WordPress coding standards rules
9. Set up notification integrations (Slack, email)

## Support

- **Bitbucket Pipelines Docs**: https://support.atlassian.com/bitbucket-cloud/docs/get-started-with-bitbucket-pipelines/
- **SSH Keys Guide**: https://support.atlassian.com/bitbucket-cloud/docs/set-up-ssh-for-git/
- **Pipeline Configuration**: https://support.atlassian.com/bitbucket-cloud/docs/configure-bitbucket-pipelinesyml/
