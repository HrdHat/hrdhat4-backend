# HrdHat v4 Backend

Supabase backend configuration for the HrdHat Daily Safety Form Application.

## Overview

This repository contains the backend infrastructure for HrdHat v4, built on Supabase which provides:

- **PostgreSQL Database**: Form instances, user data, and form modules
- **Authentication**: User signup and session management
- **Storage**: Photo uploads and PDF generation
- **Edge Functions**: Custom API endpoints and business logic
- **Real-time**: Live form collaboration (future feature)

## Tech Stack

- **Database**: Supabase (PostgreSQL)
- **Authentication**: Supabase Auth
- **Storage**: Supabase Storage
- **Edge Functions**: Deno/TypeScript
- **CLI**: Supabase CLI for local development

## Project Structure

```
backend/
├── supabase/
│   ├── config.toml           # Supabase configuration
│   ├── migrations/           # Database migrations
│   ├── functions/           # Edge functions
│   └── seed.sql            # Initial data
├── scripts/                # Deployment and utility scripts
├── docs/                   # API documentation
└── README.md
```

## Getting Started

### Prerequisites

- [Supabase CLI](https://supabase.com/docs/guides/cli)
- [Docker](https://www.docker.com/) (for local development)
- Node.js 18+ (for Edge Functions)

### Local Development

1. **Install Supabase CLI**:

   ```bash
   npm install -g supabase
   ```

2. **Start local Supabase**:

   ```bash
   supabase start
   ```

3. **Apply migrations**:

   ```bash
   supabase db reset
   ```

4. **Access local services**:
   - Database: `http://localhost:54323`
   - API: `http://localhost:54321`
   - Dashboard: `http://localhost:54323`

### Environment Variables

Create a `.env` file with:

```env
# Supabase
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key

# Database
DATABASE_URL=your_database_url
```

## Database Schema

### Core Tables

- `users` - User profiles and authentication
- `form_instances` - Individual form instances
- `form_modules` - Form sections/modules
- `form_data` - JSONB form responses
- `photos` - Uploaded images and signatures

### Key Features

- **JSONB Storage**: Flexible form data structure
- **Row Level Security**: User-based data access
- **Triggers**: Auto-timestamps and validation
- **Indexes**: Optimized queries for form retrieval

## API Endpoints

### Authentication

- `POST /auth/signup` - User registration
- `POST /auth/signin` - User login
- `POST /auth/signout` - User logout

### Forms

- `GET /forms` - List user forms
- `POST /forms` - Create new form
- `GET /forms/:id` - Get specific form
- `PUT /forms/:id` - Update form
- `DELETE /forms/:id` - Delete form

### Storage

- `POST /storage/upload` - Upload photos/signatures
- `GET /storage/:path` - Retrieve files

## Deployment

### Production Deployment

1. **Link to Supabase project**:

   ```bash
   supabase link --project-ref your-project-ref
   ```

2. **Deploy migrations**:

   ```bash
   supabase db push
   ```

3. **Deploy Edge Functions**:
   ```bash
   supabase functions deploy
   ```

### Environment Setup

- **Development**: Local Supabase instance
- **Staging**: Supabase staging project
- **Production**: Supabase production project

## Contributing

1. Create feature branch from `main`
2. Make changes and test locally
3. Run migrations and function tests
4. Submit pull request

### Development Workflow

```bash
# Start local development
supabase start

# Create new migration
supabase migration new your_migration_name

# Test migration
supabase db reset

# Deploy function
supabase functions deploy function_name
```

## Documentation

- [Database Schema](docs/database-schema.md)
- [API Reference](docs/api-reference.md)
- [Edge Functions](docs/edge-functions.md)
- [Deployment Guide](docs/deployment.md)

## Support

For backend-related issues:

1. Check Supabase logs
2. Review migration history
3. Test with local instance
4. Create issue with reproduction steps
