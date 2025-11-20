# Remote Deploy Action

Deploy files to remote servers via SSH and rsync with build support, smart exclusions, and Slack notifications. Works with any project type - WordPress, Laravel, Node.js, static sites, and more.

## Features

- Deploy to any remote server over SSH
- Run build scripts before deployment (npm, composer, custom commands)
- Execute post-deployment scripts on remote server
- Smart file exclusions with `.distignore` support
- Dry-run mode for safe testing
- Conditional Slack notifications with team appreciation messages
- Secure SSH key management
- Full rsync customization

## Quick Start

```yaml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: sultann/remote-deploy-action@v1
        with:
          remote-host: ${{ secrets.DEPLOY_HOST }}
          remote-user: deploy
          remote-key: ${{ secrets.DEPLOY_KEY }}
          target-path: /var/www/example.com
```

## Common Use Cases

### WordPress Site Deployment

Deploy a WordPress site with automatic vendor installation and cache flushing:

```yaml
- uses: sultann/remote-deploy-action@v1
  with:
    remote-host: ${{ secrets.DEPLOY_HOST }}
    remote-user: deploy
    remote-key: ${{ secrets.DEPLOY_KEY }}
    target-path: /var/www/example.com/wp-content
    ignore-file: .distignore
    script-before: composer install --no-dev --optimize-autoloader
    script-after: |
      wp cache flush --allow-root
      wp rewrite flush --allow-root
    slack-webhook: ${{ secrets.SLACK_WEBHOOK }}
    project-url: https://example.com
```

### Laravel Application Deployment

Deploy Laravel with database migrations and cache clearing:

```yaml
- uses: sultann/remote-deploy-action@v1
  with:
    remote-host: ${{ secrets.DEPLOY_HOST }}
    remote-user: deploy
    remote-key: ${{ secrets.DEPLOY_KEY }}
    target-path: /var/www/laravel-app
    ignore-file: .distignore
    script-before: |
      composer install --no-dev --optimize-autoloader
      npm ci && npm run build
    script-after: |
      php artisan migrate --force
      php artisan cache:clear
      php artisan config:cache
      php artisan queue:restart
    slack-webhook: ${{ secrets.SLACK_WEBHOOK }}
```

### Node.js Application Deployment

Deploy a Node.js app with PM2 reload:

```yaml
- uses: sultann/remote-deploy-action@v1
  with:
    remote-host: ${{ secrets.DEPLOY_HOST }}
    remote-user: deploy
    remote-key: ${{ secrets.DEPLOY_KEY }}
    target-path: /var/www/node-app
    ignore-file: .distignore
    script-before: |
      npm ci
      npm run build
    script-after: |
      pm2 reload my-app
      pm2 save
```

### Static Site Deployment

Deploy a static site (Hugo, Jekyll, etc.):

```yaml
- uses: sultann/remote-deploy-action@v1
  with:
    remote-host: ${{ secrets.DEPLOY_HOST }}
    remote-user: deploy
    remote-key: ${{ secrets.DEPLOY_KEY }}
    source-path: ./public
    target-path: /var/www/html
    script-before: hugo --minify
```

### Deploy Specific Directory

Deploy only built assets:

```yaml
- uses: sultann/remote-deploy-action@v1
  with:
    remote-host: ${{ secrets.DEPLOY_HOST }}
    remote-user: deploy
    remote-key: ${{ secrets.DEPLOY_KEY }}
    source-path: ./dist
    target-path: /var/www/app/public
```

### Testing with Dry Run

Preview what would be deployed without actually deploying:

```yaml
- uses: sultann/remote-deploy-action@v1
  with:
    remote-host: ${{ secrets.DEPLOY_HOST }}
    remote-user: deploy
    remote-key: ${{ secrets.DEPLOY_KEY }}
    target-path: /var/www/example.com
    dry-run: true
```

### Slack Notifications

Get notified in Slack for all deployments:

```yaml
- uses: sultann/remote-deploy-action@v1
  with:
    remote-host: ${{ secrets.DEPLOY_HOST }}
    remote-user: deploy
    remote-key: ${{ secrets.DEPLOY_KEY }}
    target-path: /var/www/app
    slack-webhook: ${{ secrets.SLACK_WEBHOOK }}
    slack-notify: always
    project-url: https://myapp.com
```

## Configuration

### Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `remote-host` | Remote server hostname or IP address | Yes | - |
| `remote-user` | Remote SSH username | Yes | - |
| `remote-key` | SSH private key content | Yes | - |
| `remote-port` | Remote SSH port | No | `22` |
| `source-path` | Local source directory relative to workspace | No | `./` |
| `target-path` | Remote target directory (absolute path) | Yes | - |
| `ignore-file` | Path to exclusion file (supports negation with `!`) | No | `.distignore` |
| `script-before` | Script to run locally before deployment | No | - |
| `script-after` | Script to run on remote server after deployment | No | - |
| `dry-run` | Preview deployment without actually deploying | No | `false` |
| `rsync-options` | Custom rsync options | No | `-avz --delete` |
| `slack-webhook` | Slack webhook URL for notifications | No | - |
| `slack-notify` | When to send Slack notification | No | `success` |
| `project-url` | Project URL for notifications | No | Repository name |

### Default Exclusions

The action **always** excludes `node_modules/` by default. You can add additional exclusions using the `ignore-file` parameter.

### Ignore File Format

The action reads standard gitignore-style files. Create a `.distignore` or custom file:

```
# .distignore example
tests/
*.md
!README.md
.env
uploads/
backup/
*.log
```

### Slack Notification Options

The `slack-notify` input controls when notifications are sent:

- `success` - Only notify on successful deployments (default)
- `failure` - Only notify on failed deployments
- `always` - Notify on both success and failure

Each successful deployment includes a random, appreciative team message to keep morale high!

## How It Works

The action follows these steps:

1. Validates all required inputs
2. Runs your `script-before` locally (if provided)
3. Sets up SSH connection using your private key
4. Prepares the remote directory
5. Builds exclusion list from hardcoded defaults, exclude file, and manual paths
6. Deploys files using rsync with your options
7. Runs `script-after` on the remote server (if provided)
8. Sends Slack notification (if configured)

If any step fails, the action stops and reports the error.

## SSH Key Setup

### Generate SSH Key Pair

On your local machine:

```bash
ssh-keygen -t rsa -b 4096 -C "deploy@example.com"
```

Press Enter to use the default path. This creates:
- `~/.ssh/id_rsa` (private key)
- `~/.ssh/id_rsa.pub` (public key)

### Add Public Key to Remote Server

Copy your public key to the server:

```bash
ssh-copy-id -i ~/.ssh/id_rsa.pub deploy@your-server-ip
```

Or manually append it to `~/.ssh/authorized_keys` on the remote server.

### Add Private Key to GitHub Secrets

1. Copy your private key:
   ```bash
   cat ~/.ssh/id_rsa
   ```

2. Go to your GitHub repository → Settings → Secrets and Variables → Actions

3. Click "New repository secret"

4. Name: `DEPLOY_KEY`

5. Value: Paste the entire private key (including `-----BEGIN` and `-----END` lines)

6. Add other secrets:
   - `DEPLOY_HOST` - Your server IP or hostname
   - `SLACK_WEBHOOK` - Your Slack webhook URL (optional)

## Troubleshooting

**No changes detected**

The action excluded everything. Check your `ignore-file`. Run with `dry-run: true` to see what would be deployed.

**Permission denied (publickey)**

The SSH key setup is incorrect. Verify:
- The public key is in `~/.ssh/authorized_keys` on the remote server
- The private key in GitHub secrets is complete (including header/footer)
- The remote user has permission to write to the target path

**Rsync: command not found**

Rsync is not installed on the remote server. Install it:
```bash
# Ubuntu/Debian
sudo apt-get install rsync

# CentOS/RHEL
sudo yum install rsync
```

**Target directory permission denied**

The remote user doesn't have write permission to `target-path`. Either:
- Change ownership: `sudo chown -R deploy:deploy /var/www/app`
- Or use a path the user owns

**Script-after command not found**

The command (like `wp`, `php artisan`, `pm2`) isn't in the PATH or not installed on the remote server. Use full paths or install the required tools.

## Security Notes

⚠️ **Important Security Considerations:**

1. **SSH Host Key Verification**: This action uses `StrictHostKeyChecking=no` for automated deployments. This is common practice in CI/CD environments but means the action cannot verify the remote server's identity. Only use this action with servers you trust.

2. **--delete Flag**: The default rsync options include `--delete`, which **removes files on the remote server that don't exist in your source**. This keeps the remote directory in sync but can delete important files if not careful. To disable this behavior, set:
   ```yaml
   rsync-options: '-avz'  # without --delete
   ```

3. **Private Keys**: SSH private keys are handled securely by GitHub Secrets and never exposed in logs. Never commit private keys to your repository.

4. **script-after Commands**: Commands in `script-after` run with the remote user's permissions. Ensure your deployment user has minimal necessary permissions (not root).

## Examples

### Complete WordPress Workflow

```yaml
name: Deploy WordPress Site

on:
  push:
    branches: [main]

jobs:
  deploy:
    name: Deploy to Production
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.2'
          tools: composer

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install Dependencies
        run: |
          composer install --no-dev --optimize-autoloader
          npm ci

      - name: Build Assets
        run: npm run build

      - name: Deploy to Server
        uses: sultann/remote-deploy-action@v1
        with:
          remote-host: ${{ secrets.DEPLOY_HOST }}
          remote-user: deploy
          remote-key: ${{ secrets.DEPLOY_KEY }}
          target-path: /var/www/example.com/wp-content
          ignore-file: .distignore
          script-after: |
            wp cache flush --allow-root
            wp transient delete --all --allow-root
          slack-webhook: ${{ secrets.SLACK_WEBHOOK }}
          project-url: https://example.com
```

### Multi-Environment Deployment

```yaml
name: Deploy to Environments

on:
  push:
    branches: [develop, main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Deploy to Staging
        if: github.ref == 'refs/heads/develop'
        uses: sultann/remote-deploy-action@v1
        with:
          remote-host: ${{ secrets.STAGING_HOST }}
          remote-user: deploy
          remote-key: ${{ secrets.DEPLOY_KEY }}
          target-path: /var/www/staging
          project-url: https://staging.example.com

      - name: Deploy to Production
        if: github.ref == 'refs/heads/main'
        uses: sultann/remote-deploy-action@v1
        with:
          remote-host: ${{ secrets.PRODUCTION_HOST }}
          remote-user: deploy
          remote-key: ${{ secrets.DEPLOY_KEY }}
          target-path: /var/www/production
          slack-webhook: ${{ secrets.SLACK_WEBHOOK }}
          project-url: https://example.com
```

## Version & Release Notes

When referencing this action in your workflow, you can use:

- `@v1` - Latest v1.x release (recommended for stability)
- `@v1.0.0` - Specific version (for maximum reproducibility)
- `@main` - Latest commit (not recommended for production)

After your first release, create a git tag:

```bash
git tag -a v1.0.0 -m "First release"
git push origin v1.0.0
git tag -a v1 -m "v1 major version"
git push origin v1 --force  # Update v1 tag to latest v1.x
```

## License

MIT License. Use this however you want.

## Author

Sultan Nasir Uddin ([sultann](https://github.com/sultann))