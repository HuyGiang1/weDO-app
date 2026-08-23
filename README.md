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


Requirements
Java 21
Flutter
Docker Desktop
Git
Documentation

Project specifications are located in /docs:

Product Requirement Overview
BA Consolidated Specification
ERD & Database Design
API Contract & Backend Implementation Blueprint
System Architecture Blueprint
Development Plan & Milestones
Run Local Infrastructure
docker compose -f infra/docker-compose.yml up -d

Check:

docker compose -f infra/docker-compose.yml ps
Run Backend
cd backend
./mvnw spring-boot:run

Backend:

http://localhost:8080

Health:

GET http://localhost:8080/api/v1/health

Swagger:

http://localhost:8080/swagger-ui/index.html
Run Flutter
cd mobile
flutter pub get
flutter run
Architecture

weDO uses:

Monorepo
Spring Boot Modular Monolith
Flutter Feature-first architecture
PostgreSQL as persistent source of truth
Redis for ephemeral realtime state
REST APIs
WebSocket for realtime communication
Branch Strategy
main
  ↑
dev
  ↑
feat/*
main: stable/demo-ready code
dev: integration branch
feat/*: feature development branches

Example:

feat/auth-security
feat/group-core
feat/activity
feat/chat-rest
feat/chat-realtime
feat/finance-expense