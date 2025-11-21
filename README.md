# Remote Deploy Action

Deploy files to remote servers via SSH and rsync with build support and Slack notifications.

## Quick Start

```yaml
- uses: sultann/remote-deploy-action@v1
  with:
    remote-host: ${{ secrets.DEPLOY_HOST }}
    remote-user: deploy
    remote-key: ${{ secrets.DEPLOY_KEY }}
    target-path: /var/www/example.com
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `remote-host` | Remote server hostname or IP | Yes | - |
| `remote-user` | SSH username | Yes | - |
| `remote-key` | SSH private key content | Yes | - |
| `remote-port` | SSH port | No | `22` |
| `source-path` | Local source directory | No | `./` |
| `target-path` | Remote target directory (absolute) | Yes | - |
| `ignore-file` | Exclusion file path | No | `.distignore` |
| `script-before` | Script to run locally before deploy | No | - |
| `script-after` | Script to run on remote after deploy | No | - |
| `dry-run` | Preview without deploying | No | `false` |
| `rsync-options` | Custom rsync options | No | `-avz --delete` |
| `slack-webhook` | Slack webhook URL | No | - |
| `slack-notify` | When to notify: `success`, `failure`, `always` | No | `success` |
| `project-url` | Project URL for notifications | No | Repo name |

## Examples

### WordPress Deployment

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

### With Build Process

```yaml
- uses: sultann/remote-deploy-action@v1
  with:
    remote-host: ${{ secrets.DEPLOY_HOST }}
    remote-user: deploy
    remote-key: ${{ secrets.DEPLOY_KEY }}
    target-path: /var/www/app
    script-before: |
      composer install --no-dev --optimize-autoloader
      npm ci && npm run build
    slack-webhook: ${{ secrets.SLACK_WEBHOOK }}
```

## Development

Test the action locally:

```bash
# Set required environment variables
export REMOTE_HOST="your-server.com"
export SOURCE_PATH="./"
export TARGET_PATH="/var/www/test"
export IGNORE_FILE=".distignore"
export RSYNC_OPTIONS="-avz --delete"
export DRY_RUN="true"
export SCRIPT_AFTER=""
export GITHUB_WORKSPACE=$(pwd)

# Run the deploy script
./deploy.sh
```

For real deployment, remove `DRY_RUN` and ensure SSH key is configured:

```bash
ssh-add ~/.ssh/id_rsa
ssh-add -l  # Verify key is loaded
```

## Ignore File Format

Create a `.distignore` file (gitignore-style):

```
tests/
*.md
!README.md
.env
*.log
```

## Security Notes

- Uses `StrictHostKeyChecking=no` for automated deployments
- Default `--delete` flag removes files on remote not in source
- Never commit private keys to repository

## License

MIT License

## Author

Sultan Nasir Uddin ([sultann](https://github.com/sultann))