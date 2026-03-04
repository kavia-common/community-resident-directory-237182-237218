# Backend Developer Quickstart Guide

## 🚀 Quick Connection

```python
# Python (FastAPI + SQLAlchemy or psycopg2)
DATABASE_URL = "postgresql://appuser:dbuser123@localhost:5000/myapp"

# Or use environment variables:
import os
DATABASE_URL = f"postgresql://{os.getenv('POSTGRES_USER')}:{os.getenv('POSTGRES_PASSWORD')}@localhost:{os.getenv('POSTGRES_PORT')}/{os.getenv('POSTGRES_DB')}"
```

---

## 📋 Environment Variables

Source from: `db_visualizer/postgres.env`

```bash
POSTGRES_URL="postgresql://localhost:5000/myapp"
POSTGRES_USER="appuser"
POSTGRES_PASSWORD="dbuser123"
POSTGRES_DB="myapp"
POSTGRES_PORT="5000"
```

---

## 🔑 Test Credentials

### Admin
- Email: `admin@building.com`
- Password: `admin123` (bcrypt hashed in DB)
- Role: `admin`

### Resident
- Email: `john.doe@email.com`
- Password: `resident123` (bcrypt hashed in DB)
- Role: `resident`

---

## 📊 Database Schema Summary

### Core Tables
```
roles (2 records)
  ↓
users (5 records) ← audit_logs
  ↓
resident_profiles (4 records)

users ← invitations (2 records)
users ← announcements (3 records)
users ← messages (2 records)
```

---

## 🔍 Essential Queries

### 1. Authenticate User
```sql
SELECT u.id, u.email, u.password_hash, u.role_id, r.name as role_name
FROM users u
LEFT JOIN roles r ON u.role_id = r.id
WHERE u.email = $1 AND u.is_active = true;
```

### 2. Get User Profile
```sql
SELECT 
    u.id, u.email, r.name as role_name,
    rp.first_name, rp.last_name, rp.unit_number, rp.floor_number
FROM users u
LEFT JOIN roles r ON u.role_id = r.id
LEFT JOIN resident_profiles rp ON u.id = rp.user_id
WHERE u.id = $1;
```

### 3. List Residents (with search)
```sql
SELECT 
    rp.first_name, rp.last_name, rp.unit_number, rp.floor_number,
    u.email, u.is_active
FROM resident_profiles rp
JOIN users u ON rp.user_id = u.id
WHERE 
    ($1 = '' OR rp.first_name ILIKE $1 OR rp.last_name ILIKE $1)
    AND ($2 = '' OR rp.unit_number = $2)
    AND ($3 IS NULL OR rp.floor_number = $3)
ORDER BY rp.last_name, rp.first_name
LIMIT $4 OFFSET $5;
```

### 4. Get Published Announcements
```sql
SELECT a.id, a.title, a.content, a.priority, a.published_at
FROM announcements a
WHERE a.is_published = true 
    AND (a.expires_at IS NULL OR a.expires_at > NOW())
ORDER BY a.published_at DESC;
```

### 5. Get Unread Messages
```sql
SELECT m.id, m.subject, m.content, m.created_at
FROM messages m
WHERE m.recipient_id = $1 AND m.is_read = false
ORDER BY m.created_at DESC;
```

### 6. Create Audit Log
```sql
INSERT INTO audit_logs 
    (user_id, action, entity_type, entity_id, details, ip_address, user_agent)
VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7);
```

---

## 🏗️ Recommended FastAPI Structure

```python
from fastapi import FastAPI, Depends, HTTPException, status
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
import bcrypt
import jwt

# Database connection
DATABASE_URL = "postgresql://appuser:dbuser123@localhost:5000/myapp"
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine)

# Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Password verification
def verify_password(plain_password: str, hashed_password: str) -> bool:
    return bcrypt.checkpw(
        plain_password.encode('utf-8'), 
        hashed_password.encode('utf-8')
    )

# Get current user (JWT)
async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
):
    # Decode JWT and get user from DB
    payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
    user_id = payload.get("sub")
    # Query user...
    return user

# RBAC decorator
def require_role(required_role: str):
    def role_checker(current_user = Depends(get_current_user)):
        if current_user.role_name != required_role:
            raise HTTPException(
                status_code=403,
                detail="Insufficient permissions"
            )
        return current_user
    return role_checker
```

---

## 📝 API Endpoints to Implement

### Authentication
- `POST /auth/login` - User login (JWT token)
- `POST /auth/register` - New user registration
- `GET /auth/me` - Get current user profile

### Residents (Public/Resident)
- `GET /residents` - List all residents (with search/filter)
- `GET /residents/{id}` - Get resident by ID
- `PUT /residents/me` - Update own profile

### Admin - Residents
- `POST /admin/residents` - Create resident
- `PUT /admin/residents/{id}` - Update resident
- `DELETE /admin/residents/{id}` - Delete resident
- `PATCH /admin/residents/{id}/status` - Activate/deactivate

### Admin - Invitations
- `GET /admin/invitations` - List invitations
- `POST /admin/invitations` - Send invitation
- `DELETE /admin/invitations/{id}` - Cancel invitation

### Invitations (Public)
- `GET /invitations/{code}` - Verify invitation code
- `POST /invitations/{code}/accept` - Accept invitation

### Announcements (Public/Resident)
- `GET /announcements` - List published announcements
- `GET /announcements/{id}` - Get announcement details

### Admin - Announcements
- `GET /admin/announcements` - List all announcements
- `POST /admin/announcements` - Create announcement
- `PUT /admin/announcements/{id}` - Update announcement
- `DELETE /admin/announcements/{id}` - Delete announcement

### Messages (Resident)
- `GET /messages/inbox` - Get received messages
- `GET /messages/sent` - Get sent messages
- `GET /messages/{id}` - Get message details
- `POST /messages` - Send message
- `PATCH /messages/{id}/read` - Mark as read
- `DELETE /messages/{id}` - Delete message

### Audit Logs (Admin)
- `GET /admin/audit-logs` - View audit logs
- `GET /admin/audit-logs/stats` - Audit statistics

---

## 🔒 Security Checklist

- ✅ Use bcrypt for password hashing (cost factor 12+)
- ✅ Implement JWT authentication with expiry
- ✅ Validate RBAC on every protected endpoint
- ✅ Use parameterized queries (prevent SQL injection)
- ✅ Create audit logs for all important actions
- ✅ Validate invitation expiry before acceptance
- ✅ Check user ownership before updates/deletes
- ✅ Sanitize user input
- ✅ Implement rate limiting
- ✅ Use HTTPS in production

---

## 📚 Reference Files

- **Full Schema:** `schema_documentation.md`
- **SQL Queries:** `backend_sql_reference.sql`
- **Verification:** `schema_verification.md`
- **Connection:** `db_connection.txt`

---

## 🧪 Testing

### Quick Test Connection
```bash
psql postgresql://appuser:dbuser123@localhost:5000/myapp -c "SELECT COUNT(*) FROM users;"
```

### Visual Inspection
- Database Visualizer: https://vscode-internal-13987-qa.qa01.cloud.kavia.ai:5001

---

## 💡 Tips

1. **Transactions:** Use database transactions for multi-step operations (e.g., create user + profile)
2. **Pagination:** Always implement pagination for list endpoints (default: limit=50)
3. **Timestamps:** Auto-update `updated_at` on every UPDATE
4. **Null Handling:** Use `COALESCE` for optional field updates
5. **Search:** Use `ILIKE '%term%'` for case-insensitive search
6. **Indexes:** All common query patterns are indexed
7. **Cascading:** User deletion cascades to profile and received messages
8. **Audit Everything:** Log login, create, update, delete operations

---

**Ready to build? Start with authentication endpoints first! 🎯**
