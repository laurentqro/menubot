# Menubot

Daily school menu notifier for Monaco nurseries. Fetches the weekly menu PDF from the school website, extracts the day's menu using AI, and sends it via email.

## Features

- Automatic PDF fetching from school website
- AI-powered menu extraction (Claude)
- Email delivery via Mailgun
- Menu caching (avoids repeated API calls)
- Holiday, weekend, and Wednesday detection (no lunch on Wednesdays)
- Docker-based scheduling

## Quick Start

### Prerequisites

- Ruby 3.2+ (for local development)
- Docker (for production deployment)
- Anthropic API key
- Mailgun account

### Environment Variables

Create a `.env` file:

```bash
ANTHROPIC_API_KEY=sk-ant-...
MAILGUN_API_KEY=...
MAILGUN_DOMAIN=mg.yourdomain.com
FROM_EMAIL=menubot@yourdomain.com
TO_EMAIL=parent@example.com
```

## CLI Usage

```bash
# Preview today's menu
bin/menubot preview

# Preview a specific date
bin/menubot preview --date 2025-12-05

# Send today's menu email
bin/menubot run

# Fetch latest PDF only
bin/menubot fetch

# Show help
bin/menubot --help
```

## Docker Deployment

The recommended way to run menubot in production:

```bash
# Start (runs daily at 7 AM Paris time, Mon-Tue, Thu-Fri)
docker compose up -d

# Watch logs
docker compose logs -f

# Manual preview
docker compose run --rm --entrypoint /app/bin/menubot menubot preview

# Manual run
docker compose run --rm --entrypoint /app/bin/menubot menubot run

# Stop
docker compose down
```

The container uses [supercronic](https://github.com/aptible/supercronic) for scheduling and automatically restarts on server reboot.

## Configuration

Edit `config.yml` to customize:

- School name and website
- Email subject template
- Holiday dates
- LLM model

## Development

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rake

# Build Docker image
docker compose build
```

## How It Works

1. Fetches the menu PDF from the school website
2. Checks cache for previously extracted menus
3. If not cached, sends PDF to Claude for extraction
4. Caches the result (keyed by PDF checksum + date)
5. Sends formatted email via Mailgun

The cache automatically invalidates when the school uploads a new PDF.

## License

MIT
