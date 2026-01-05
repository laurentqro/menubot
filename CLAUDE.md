# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Menubot is a daily school menu notifier for Monaco nurseries. It fetches weekly menu PDFs from a school website, extracts the day's menu using Claude AI, and sends it via Mailgun email.

## Commands

```bash
# Run tests (default rake task)
bundle exec rake

# Run a single test file
bundle exec ruby -Ilib:test test/menubot_holidays_test.rb

# Run a specific test method
bundle exec ruby -Ilib:test test/menubot_holidays_test.rb -n test_holiday_returns_true_for_christmas

# Preview menu for today
bin/menubot preview

# Preview menu for specific date
bin/menubot preview --date 2025-12-05

# Send menu email (production)
bin/menubot run

# Fetch latest PDF only
bin/menubot fetch

# Docker: run in production (daily at 7AM Paris time)
docker compose up -d

# Docker: manual commands
docker compose run --rm --entrypoint /app/bin/menubot menubot preview
docker compose run --rm --entrypoint /app/bin/menubot menubot run
```

## Architecture

The codebase follows a simple module-based structure:

- **`lib/menubot.rb`**: Main orchestration module with `run`, `preview`, and `fetch_latest_menu` entry points. Configures RubyLLM and French I18n translations. Contains the LLM prompt for menu extraction.
- **`lib/menubot/config.rb`**: YAML configuration loader (`config.yml`) with class method accessors for school info, email templates, LLM model, and holidays.
- **`lib/menubot/menu_cache.rb`**: JSON file cache keyed by PDF checksum + date. Automatically invalidates when school uploads new PDFs.
- **`lib/tracker.rb`**: Prevents duplicate emails by tracking last run date in `data/last_run.json`.

### Data Flow

1. `fetch_latest_menu` scrapes school website for PDF link, downloads to `data/menus.pdf`
2. `get_menu_of_the_day` checks cache, or sends PDF to Claude via RubyLLM
3. Cache stores extracted menu text (keyed by `MD5(pdf)_YYYY-MM-DD`)
4. `run` sends email via Mailgun, marks run complete in tracker

### Key Dependencies

- **ruby_llm**: AI model abstraction (Claude/OpenAI)
- **mailgun-ruby**: Email delivery
- **nokogiri**: HTML parsing for PDF link scraping
- **activesupport**: Date extensions (`saturday?`, `sunday?`)

## Configuration

Edit `config.yml` for school settings, LLM model, and holiday dates (French format "jour mois").

Environment variables (`.env`):
- `ANTHROPIC_API_KEY` / `OPENAI_API_KEY`
- `MAILGUN_API_KEY`, `MAILGUN_DOMAIN`
- `FROM_EMAIL`, `TO_EMAIL`

## Testing

Tests use Minitest with `Date.stub` for date-dependent logic. Test files are in `test/` directory.
