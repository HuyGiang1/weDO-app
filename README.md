# weDO

weDO is a mobile platform for private group communication, activities, collaboration and shared finance.

## Tech Stack

### Mobile
- Flutter
- Dart

### Backend
- Java 21
- Spring Boot
- Spring Security
- Spring Data JPA
- WebSocket
- Redis

### Database
- PostgreSQL
- Flyway

### Infrastructure
- Docker Compose
- Firebase Cloud Messaging
- Object Storage

## Repository Structure

```text
weDO-app/
├── backend/             # Spring Boot backend
├── mobile/              # Flutter application
├── docs/                # Product and technical specifications
├── infra/               # PostgreSQL + Redis local infrastructure
└── .github/workflows/   # CI/CD workflows
```

## Requirements

Before running the project, install:

- Java 21
- Flutter
- Docker Desktop
- Git

## Documentation

Project specifications are located in `/docs`.

Important documents:

- Product Requirement Overview
- BA Consolidated Specification
- ERD & Database Design
- API Contract & Backend Implementation Blueprint
- System Architecture Blueprint
- Development Plan & Milestones

These documents are the baseline for implementation and should be reviewed before changing business rules, API contracts, database structure, or system architecture.

## Local Environment Variables

Copy the example environment configuration if needed:

```bash
cp .env.example .env
```

Default local values are provided so the project can run without custom environment configuration.

Example:

```env
WEDO_DB_NAME=wedo
WEDO_DB_URL=jdbc:postgresql://localhost:5432/wedo
WEDO_DB_USERNAME=wedo
WEDO_DB_PASSWORD=wedo_local

WEDO_REDIS_HOST=localhost
WEDO_REDIS_PORT=6379
```

Do not commit real production secrets.

## Run Local Infrastructure

From the repository root:

```bash
docker compose -f infra/docker-compose.yml up -d
```

Check the containers:

```bash
docker compose -f infra/docker-compose.yml ps
```

Expected local services:

```text
PostgreSQL: localhost:5432
Redis:      localhost:6379
```

Stop local infrastructure:

```bash
docker compose -f infra/docker-compose.yml down
```

## Run Backend

Move to the backend directory:

```bash
cd backend
```

Run Spring Boot:

```bash
./mvnw spring-boot:run
```

Backend base URL:

```text
http://localhost:8080
```

Health endpoint:

```text
GET http://localhost:8080/api/v1/health
```

Spring Boot Actuator health:

```text
GET http://localhost:8080/actuator/health
```

Swagger UI:

```text
http://localhost:8080/swagger-ui/index.html
```

OpenAPI JSON:

```text
http://localhost:8080/v3/api-docs
```

## Run Flutter

Move to the mobile directory:

```bash
cd mobile
```

Install dependencies:

```bash
flutter pub get
```

Run on an available device:

```bash
flutter run
```

Run on Chrome:

```bash
flutter run -d chrome
```

Check Flutter code:

```bash
flutter analyze
```

Run Flutter tests:

```bash
flutter test
```

## Architecture

weDO uses:

- Monorepo
- Spring Boot Modular Monolith
- Flutter Feature-first architecture
- PostgreSQL as the persistent source of truth
- Redis for ephemeral realtime state
- REST APIs for business operations
- WebSocket for realtime communication
- Flyway for database migrations
- Object Storage for uploaded files
- Firebase Cloud Messaging for push notifications

### Backend Architecture

Backend code is organized by business feature under:

```text
backend/src/main/java/com/wedo/backend/
```

Planned modules include:

```text
common/
security/
auth/
user/
social/
group/
chat/
activity/
poll/
task/
discussion/
calendar/
finance/
fund/
notification/
media/
```

General dependency direction:

```text
Controller
    ↓
Service
    ↓
Repository
    ↓
PostgreSQL
```

Business rules and transactions belong in the Service layer.

JPA Entities must not be exposed directly as API responses.

### Flutter Architecture

Flutter follows a feature-first structure:

```text
mobile/lib/
├── app/
├── core/
└── features/
```

Shared infrastructure such as networking, authentication, storage, WebSocket, errors, and configuration belongs in `core/`.

Business UI and state belong in their corresponding feature.

## Development Roadmap

Development follows the milestone plan defined in:

```text
docs/DEVELOPMENT_PLAN_MILESTONES_v1.0_FULL.md
```

Main roadmap:

```text
M0  Repository + Bootstrap
M1  Database Foundation + Common Infrastructure
M2  Authentication + Security
M3  User Profile + Privacy
M4  Social / Friends / Block
M5  Group Core + Membership + Permission
M6  Invitation / Join Request / Ban / Archive
M7  Activity + RSVP + Waitlist
M8  Poll + Task + Discussion
M9  Chat REST
M10 WebSocket + Redis
M11 Expense + Balance
M12 Settlement
M13 Group Fund
M14 Notification + FCM
M15 Calendar + Reminder
M16 Media + Search
M17 Home Aggregation + Product Completion
M18 Hardening
M19 Deployment + Demo
```

## Branch Strategy

weDO uses the following branch flow:

```text
feat/*
   ↓
  dev
   ↓
 main
```

### `main`

Stable and demo-ready code.

Do not develop features directly on `main`.

### `dev`

Integration branch.

Completed feature branches are merged into `dev` first.

### `feat/*`

Each feature should be developed on its own branch.

Examples:

```text
feat/auth-security
feat/group-core
feat/activity
feat/chat-rest
feat/chat-realtime
feat/finance-expense
feat/group-fund
```

## Typical Development Workflow

Start from the latest `dev`:

```bash
git checkout dev
git pull origin dev
```

Create a feature branch:

```bash
git checkout -b feat/example-feature
```

After coding:

```bash
git add .
git commit -m "feat(example): implement example feature"
git push -u origin feat/example-feature
```

Then create a Pull Request:

```text
feat/example-feature → dev
```

After a milestone is stable and reviewed:

```text
dev → main
```

## Commit Convention

Use clear commit prefixes:

```text
feat:
fix:
test:
refactor:
docs:
chore:
```

Examples:

```text
feat(group): add group creation
test(activity): cover final slot race
fix(finance): reject invalid custom split
docs: update project architecture
chore: configure local infrastructure
```

## Current Status

M0 — Repository & Bootstrap baseline has been established.

Completed foundation includes:

- Monorepo
- Spring Boot backend
- Flutter mobile project
- PostgreSQL configuration
- Redis configuration
- Docker Compose
- Flyway
- Spring Security skeleton
- Health endpoint
- Actuator
- Swagger/OpenAPI configuration
- Environment variable baseline
- Product and technical documentation

Runtime verification for Docker and Flutter-to-backend connectivity may be completed on the active development machine before beginning the next implementation milestone.

## Team Rules

- Read the documentation in `/docs` before implementing a module.
- Do not silently change agreed business rules.
- Do not modify applied Flyway migrations.
- Do not expose JPA Entities directly through REST APIs.
- Keep authorization rules on the backend.
- Use Pull Requests for feature integration.
- Avoid pushing directly to `main`.
- Keep real passwords, tokens, API keys, and production secrets out of Git.

## Project

**weDO**

Private group communication, shared activities, collaboration and shared finance.