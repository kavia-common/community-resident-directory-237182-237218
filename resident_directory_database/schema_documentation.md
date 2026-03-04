# Resident Directory Database Schema Documentation

## Overview
This PostgreSQL database supports a resident directory application with user management, profiles, invitations, announcements, messaging, and audit logging.

## Connection Information
- **Database**: myapp
- **User**: appuser
- **Port**: 5000
- **Connection String**: `psql postgresql://appuser:dbuser123@localhost:5000/myapp`

## Database Tables

### 1. roles
Manages user roles (admin/resident) for role-based access control.

**Columns:**
- `id` (SERIAL PRIMARY KEY): Unique role identifier
- `name` (VARCHAR(50) UNIQUE NOT NULL): Role name (e.g., 'admin', 'resident')
- `description` (TEXT): Role description
- `created_at` (TIMESTAMP): Record creation timestamp
- `updated_at` (TIMESTAMP): Last update timestamp

**Seed Data:**
- admin: Administrator with full system access
- resident: Regular resident with standard access

---

### 2. users
Stores user authentication and account information.

**Columns:**
- `id` (SERIAL PRIMARY KEY): Unique user identifier
- `email` (VARCHAR(255) UNIQUE NOT NULL): User email address (login)
- `password_hash` (VARCHAR(255) NOT NULL): Bcrypt hashed password
- `role_id` (INTEGER): Foreign key to roles table
- `is_active` (BOOLEAN): Account active status
- `created_at` (TIMESTAMP): Account creation timestamp
- `updated_at` (TIMESTAMP): Last update timestamp
- `last_login` (TIMESTAMP): Last login timestamp

**Relationships:**
- `role_id` → `roles.id` (ON DELETE SET NULL)

**Indexes:**
- `idx_users_email` on `email`
- `idx_users_role_id` on `role_id`

**Seed Data:**
- admin@building.com (admin role, password: admin123)
- john.doe@email.com (resident role)
- jane.smith@email.com (resident role)
- mike.johnson@email.com (resident role)
- sarah.williams@email.com (resident role)

---

### 3. resident_profiles
Extended profile information for residents.

**Columns:**
- `id` (SERIAL PRIMARY KEY): Unique profile identifier
- `user_id` (INTEGER UNIQUE): Foreign key to users table
- `first_name` (VARCHAR(100) NOT NULL): Resident first name
- `last_name` (VARCHAR(100) NOT NULL): Resident last name
- `phone` (VARCHAR(20)): Contact phone number
- `unit_number` (VARCHAR(20)): Apartment/unit number
- `floor_number` (INTEGER): Floor number
- `building` (VARCHAR(50)): Building identifier
- `move_in_date` (DATE): Date resident moved in
- `profile_image_url` (TEXT): URL to profile image
- `bio` (TEXT): Resident biography/about text
- `created_at` (TIMESTAMP): Profile creation timestamp
- `updated_at` (TIMESTAMP): Last update timestamp

**Relationships:**
- `user_id` → `users.id` (ON DELETE CASCADE)

**Indexes:**
- `idx_resident_profiles_name` on `(last_name, first_name)`
- `idx_resident_profiles_unit` on `unit_number`
- `idx_resident_profiles_floor` on `floor_number`

**Seed Data:**
- 4 sample residents with complete profile information

---

### 4. invitations
Manages resident invitation and onboarding process.

**Columns:**
- `id` (SERIAL PRIMARY KEY): Unique invitation identifier
- `email` (VARCHAR(255) NOT NULL): Invitee email address
- `invitation_code` (VARCHAR(100) UNIQUE NOT NULL): Unique invitation code
- `invited_by` (INTEGER): Foreign key to users table (admin who sent)
- `status` (VARCHAR(20)): Invitation status (pending/accepted/expired)
- `unit_number` (VARCHAR(20)): Assigned unit number
- `floor_number` (INTEGER): Assigned floor number
- `expires_at` (TIMESTAMP NOT NULL): Invitation expiration date
- `accepted_at` (TIMESTAMP): Date invitation was accepted
- `created_at` (TIMESTAMP): Invitation creation timestamp
- `updated_at` (TIMESTAMP): Last update timestamp

**Relationships:**
- `invited_by` → `users.id` (ON DELETE SET NULL)

**Indexes:**
- `idx_invitations_code` on `invitation_code`
- `idx_invitations_status` on `status`

**Seed Data:**
- 1 pending invitation
- 1 accepted invitation (for John Doe)

---

### 5. announcements
Community-wide announcements from administrators.

**Columns:**
- `id` (SERIAL PRIMARY KEY): Unique announcement identifier
- `title` (VARCHAR(255) NOT NULL): Announcement title
- `content` (TEXT NOT NULL): Announcement content/body
- `author_id` (INTEGER): Foreign key to users table (admin author)
- `priority` (VARCHAR(20)): Priority level (normal/high/urgent)
- `is_published` (BOOLEAN): Publication status
- `published_at` (TIMESTAMP): Publication timestamp
- `expires_at` (TIMESTAMP): Optional expiration date
- `created_at` (TIMESTAMP): Creation timestamp
- `updated_at` (TIMESTAMP): Last update timestamp

**Relationships:**
- `author_id` → `users.id` (ON DELETE SET NULL)

**Indexes:**
- `idx_announcements_published` on `published_at DESC`
- `idx_announcements_is_published` on `is_published`

**Seed Data:**
- 3 sample announcements (welcome message, maintenance notice, event)

---

### 6. messages
Direct messaging between residents and administrators.

**Columns:**
- `id` (SERIAL PRIMARY KEY): Unique message identifier
- `sender_id` (INTEGER): Foreign key to users table (sender)
- `recipient_id` (INTEGER): Foreign key to users table (recipient)
- `subject` (VARCHAR(255)): Message subject
- `content` (TEXT NOT NULL): Message content/body
- `is_read` (BOOLEAN): Read status
- `read_at` (TIMESTAMP): Date message was read
- `parent_message_id` (INTEGER): Foreign key for threaded replies
- `created_at` (TIMESTAMP): Message creation timestamp
- `updated_at` (TIMESTAMP): Last update timestamp

**Relationships:**
- `sender_id` → `users.id` (ON DELETE SET NULL)
- `recipient_id` → `users.id` (ON DELETE CASCADE)
- `parent_message_id` → `messages.id` (ON DELETE SET NULL)

**Indexes:**
- `idx_messages_sender` on `sender_id`
- `idx_messages_recipient` on `recipient_id`
- `idx_messages_is_read` on `is_read`

**Seed Data:**
- 2 sample messages (admin to resident, resident to resident)

---

### 7. audit_logs
Comprehensive audit trail for security and compliance.

**Columns:**
- `id` (SERIAL PRIMARY KEY): Unique log entry identifier
- `user_id` (INTEGER): Foreign key to users table (actor)
- `action` (VARCHAR(100) NOT NULL): Action performed
- `entity_type` (VARCHAR(50)): Type of entity affected
- `entity_id` (INTEGER): ID of affected entity
- `details` (JSONB): Additional context (JSON format)
- `ip_address` (VARCHAR(45)): IP address of request
- `user_agent` (TEXT): Browser/client user agent
- `created_at` (TIMESTAMP): Log entry timestamp

**Relationships:**
- `user_id` → `users.id` (ON DELETE SET NULL)

**Indexes:**
- `idx_audit_logs_user` on `user_id`
- `idx_audit_logs_action` on `action`
- `idx_audit_logs_created_at` on `created_at DESC`

**Seed Data:**
- 4 sample audit log entries (login, profile update, invitation sent, announcement created)

---

## Entity Relationships

```
roles (1) ←→ (many) users
users (1) ←→ (1) resident_profiles
users (1) ←→ (many) invitations (as inviter)
users (1) ←→ (many) announcements (as author)
users (1) ←→ (many) messages (as sender)
users (1) ←→ (many) messages (as recipient)
messages (1) ←→ (many) messages (threaded replies)
users (1) ←→ (many) audit_logs
```

## Performance Optimizations

### Indexes Summary
- **Authentication**: email lookups optimized
- **Search**: name, unit, and floor filtering optimized
- **Messages**: sender/recipient queries optimized
- **Audit**: chronological and action-based queries optimized
- **Announcements**: published date ordering optimized

### Query Patterns
- User authentication: O(1) via `idx_users_email`
- Resident search by name: O(log n) via `idx_resident_profiles_name`
- Unit/floor filtering: O(log n) via unit/floor indexes
- Unread messages: O(log n) via `idx_messages_is_read`
- Recent announcements: O(log n) via `idx_announcements_published`
- Audit trail queries: O(log n) via timestamp/action indexes

## Data Integrity

### Cascading Deletes
- Deleting a user cascades to their resident_profile and received messages
- Other relationships use SET NULL to preserve historical data

### Constraints
- Unique constraints on: role names, user emails, invitation codes, resident user_id
- NOT NULL constraints on critical fields (email, password, names, content)
- Foreign key constraints enforce referential integrity

## Sample Queries

### Find residents by name
```sql
SELECT rp.*, u.email 
FROM resident_profiles rp
JOIN users u ON rp.user_id = u.id
WHERE rp.last_name ILIKE '%Smith%'
ORDER BY rp.last_name, rp.first_name;
```

### Get unread messages for a user
```sql
SELECT m.*, u.email as sender_email, rp.first_name, rp.last_name
FROM messages m
JOIN users u ON m.sender_id = u.id
JOIN resident_profiles rp ON u.id = rp.user_id
WHERE m.recipient_id = 2 AND m.is_read = false
ORDER BY m.created_at DESC;
```

### Recent published announcements
```sql
SELECT a.*, rp.first_name, rp.last_name
FROM announcements a
LEFT JOIN users u ON a.author_id = u.id
LEFT JOIN resident_profiles rp ON u.id = rp.user_id
WHERE a.is_published = true 
  AND (a.expires_at IS NULL OR a.expires_at > NOW())
ORDER BY a.published_at DESC
LIMIT 10;
```

### Audit trail for a user
```sql
SELECT * FROM audit_logs
WHERE user_id = 1
ORDER BY created_at DESC
LIMIT 50;
```

## Maintenance Notes

- **Passwords**: All passwords are bcrypt hashed (cost factor 12)
- **Timestamps**: All tables use `created_at` and most use `updated_at`
- **Soft Deletes**: Not implemented; use `is_active` flag on users if needed
- **Backups**: Use provided `backup_db.sh` script for database backups
- **Restore**: Use `restore_db.sh` to restore from backup files

## Default Credentials (for testing only)

**Admin Account:**
- Email: admin@building.com
- Password: admin123

**Resident Accounts:**
- All resident emails use password: resident123

**Note**: Change these credentials in production environments!
