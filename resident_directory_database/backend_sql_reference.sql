-- Backend SQL Reference for Resident Directory Database
-- This file contains common SQL queries for backend API implementation

-- ============================================================================
-- AUTHENTICATION QUERIES
-- ============================================================================

-- Get user by email for authentication
-- Used in: POST /auth/login
SELECT u.id, u.email, u.password_hash, u.role_id, r.name as role_name, u.is_active
FROM users u
LEFT JOIN roles r ON u.role_id = r.id
WHERE u.email = $1;

-- Update last login timestamp
-- Used in: POST /auth/login (after successful authentication)
UPDATE users 
SET last_login = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
WHERE id = $1;

-- ============================================================================
-- USER MANAGEMENT QUERIES
-- ============================================================================

-- Get user profile with role and resident details
-- Used in: GET /users/me, GET /users/{user_id}
SELECT 
    u.id, u.email, u.is_active, u.created_at, u.last_login,
    r.name as role_name,
    rp.first_name, rp.last_name, rp.phone, rp.unit_number, 
    rp.floor_number, rp.building, rp.move_in_date, 
    rp.profile_image_url, rp.bio
FROM users u
LEFT JOIN roles r ON u.role_id = r.id
LEFT JOIN resident_profiles rp ON u.id = rp.user_id
WHERE u.id = $1;

-- Create new user (for invitation acceptance)
-- Used in: POST /auth/register, POST /invitations/{code}/accept
INSERT INTO users (email, password_hash, role_id, is_active)
VALUES ($1, $2, $3, true)
RETURNING id, email, created_at;

-- Update user status
-- Used in: PATCH /admin/users/{user_id}/status
UPDATE users 
SET is_active = $1, updated_at = CURRENT_TIMESTAMP
WHERE id = $2
RETURNING id, email, is_active;

-- ============================================================================
-- RESIDENT PROFILE QUERIES
-- ============================================================================

-- List all residents with search and filter
-- Used in: GET /residents?search=&unit=&floor=
SELECT 
    rp.id, rp.first_name, rp.last_name, rp.phone,
    rp.unit_number, rp.floor_number, rp.building,
    rp.move_in_date, rp.profile_image_url, rp.bio,
    u.email, u.is_active
FROM resident_profiles rp
JOIN users u ON rp.user_id = u.id
WHERE 
    ($1 = '' OR rp.first_name ILIKE $1 OR rp.last_name ILIKE $1)
    AND ($2 = '' OR rp.unit_number = $2)
    AND ($3 IS NULL OR rp.floor_number = $3)
ORDER BY rp.last_name, rp.first_name
LIMIT $4 OFFSET $5;

-- Get resident count (for pagination)
-- Used in: GET /residents (for total count)
SELECT COUNT(*) 
FROM resident_profiles rp
JOIN users u ON rp.user_id = u.id
WHERE 
    ($1 = '' OR rp.first_name ILIKE $1 OR rp.last_name ILIKE $1)
    AND ($2 = '' OR rp.unit_number = $2)
    AND ($3 IS NULL OR rp.floor_number = $3);

-- Create resident profile
-- Used in: POST /residents, POST /invitations/{code}/accept
INSERT INTO resident_profiles 
    (user_id, first_name, last_name, phone, unit_number, floor_number, 
     building, move_in_date, profile_image_url, bio)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
RETURNING id, user_id, first_name, last_name, unit_number, floor_number, created_at;

-- Update resident profile
-- Used in: PUT /residents/{user_id}, PATCH /residents/me
UPDATE resident_profiles
SET 
    first_name = COALESCE($1, first_name),
    last_name = COALESCE($2, last_name),
    phone = COALESCE($3, phone),
    unit_number = COALESCE($4, unit_number),
    floor_number = COALESCE($5, floor_number),
    building = COALESCE($6, building),
    move_in_date = COALESCE($7, move_in_date),
    profile_image_url = COALESCE($8, profile_image_url),
    bio = COALESCE($9, bio),
    updated_at = CURRENT_TIMESTAMP
WHERE user_id = $10
RETURNING id, user_id, first_name, last_name, unit_number, updated_at;

-- Delete resident (cascades to profile via FK)
-- Used in: DELETE /admin/residents/{user_id}
DELETE FROM users WHERE id = $1;

-- ============================================================================
-- INVITATION QUERIES
-- ============================================================================

-- Create invitation
-- Used in: POST /admin/invitations
INSERT INTO invitations 
    (email, invitation_code, invited_by, unit_number, floor_number, expires_at)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING id, email, invitation_code, unit_number, floor_number, expires_at, created_at;

-- Get invitation by code (for validation)
-- Used in: GET /invitations/{code}, POST /invitations/{code}/accept
SELECT id, email, invitation_code, invited_by, status, 
       unit_number, floor_number, expires_at, accepted_at
FROM invitations
WHERE invitation_code = $1;

-- List all invitations
-- Used in: GET /admin/invitations?status=
SELECT 
    i.id, i.email, i.invitation_code, i.status,
    i.unit_number, i.floor_number, i.expires_at, i.accepted_at, i.created_at,
    u.email as invited_by_email
FROM invitations i
LEFT JOIN users u ON i.invited_by = u.id
WHERE ($1 = '' OR i.status = $1)
ORDER BY i.created_at DESC
LIMIT $2 OFFSET $3;

-- Accept invitation
-- Used in: POST /invitations/{code}/accept
UPDATE invitations
SET status = 'accepted', accepted_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
WHERE invitation_code = $1 AND status = 'pending' AND expires_at > NOW()
RETURNING id, email, unit_number, floor_number;

-- Expire old invitations (background task)
UPDATE invitations
SET status = 'expired', updated_at = CURRENT_TIMESTAMP
WHERE status = 'pending' AND expires_at <= NOW();

-- ============================================================================
-- ANNOUNCEMENT QUERIES
-- ============================================================================

-- List published announcements (for residents)
-- Used in: GET /announcements
SELECT 
    a.id, a.title, a.content, a.priority, a.published_at, a.expires_at,
    rp.first_name || ' ' || rp.last_name as author_name
FROM announcements a
LEFT JOIN users u ON a.author_id = u.id
LEFT JOIN resident_profiles rp ON u.id = rp.user_id
WHERE a.is_published = true 
    AND (a.expires_at IS NULL OR a.expires_at > NOW())
ORDER BY a.published_at DESC
LIMIT $1 OFFSET $2;

-- List all announcements (for admins)
-- Used in: GET /admin/announcements
SELECT 
    a.id, a.title, a.content, a.priority, a.is_published, 
    a.published_at, a.expires_at, a.created_at,
    rp.first_name || ' ' || rp.last_name as author_name
FROM announcements a
LEFT JOIN users u ON a.author_id = u.id
LEFT JOIN resident_profiles rp ON u.id = rp.user_id
ORDER BY a.created_at DESC
LIMIT $1 OFFSET $2;

-- Get single announcement
-- Used in: GET /announcements/{id}
SELECT 
    a.id, a.title, a.content, a.priority, a.is_published,
    a.published_at, a.expires_at, a.created_at, a.updated_at,
    rp.first_name || ' ' || rp.last_name as author_name,
    u.email as author_email
FROM announcements a
LEFT JOIN users u ON a.author_id = u.id
LEFT JOIN resident_profiles rp ON u.id = rp.user_id
WHERE a.id = $1;

-- Create announcement
-- Used in: POST /admin/announcements
INSERT INTO announcements (title, content, author_id, priority, is_published, published_at, expires_at)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING id, title, priority, is_published, published_at, created_at;

-- Update announcement
-- Used in: PUT /admin/announcements/{id}
UPDATE announcements
SET 
    title = COALESCE($1, title),
    content = COALESCE($2, content),
    priority = COALESCE($3, priority),
    is_published = COALESCE($4, is_published),
    published_at = COALESCE($5, published_at),
    expires_at = COALESCE($6, expires_at),
    updated_at = CURRENT_TIMESTAMP
WHERE id = $7
RETURNING id, title, priority, is_published, published_at, updated_at;

-- Delete announcement
-- Used in: DELETE /admin/announcements/{id}
DELETE FROM announcements WHERE id = $1;

-- ============================================================================
-- MESSAGE QUERIES
-- ============================================================================

-- Get user's received messages
-- Used in: GET /messages/inbox
SELECT 
    m.id, m.subject, m.content, m.is_read, m.read_at, m.created_at,
    m.parent_message_id,
    sender_rp.first_name || ' ' || sender_rp.last_name as sender_name,
    sender_u.email as sender_email
FROM messages m
LEFT JOIN users sender_u ON m.sender_id = sender_u.id
LEFT JOIN resident_profiles sender_rp ON sender_u.id = sender_rp.user_id
WHERE m.recipient_id = $1
ORDER BY m.created_at DESC
LIMIT $2 OFFSET $3;

-- Get user's sent messages
-- Used in: GET /messages/sent
SELECT 
    m.id, m.subject, m.content, m.is_read, m.read_at, m.created_at,
    m.parent_message_id,
    recipient_rp.first_name || ' ' || recipient_rp.last_name as recipient_name,
    recipient_u.email as recipient_email
FROM messages m
LEFT JOIN users recipient_u ON m.recipient_id = recipient_u.id
LEFT JOIN resident_profiles recipient_rp ON recipient_u.id = recipient_rp.user_id
WHERE m.sender_id = $1
ORDER BY m.created_at DESC
LIMIT $2 OFFSET $3;

-- Get unread message count
-- Used in: GET /messages/unread-count
SELECT COUNT(*) as unread_count
FROM messages
WHERE recipient_id = $1 AND is_read = false;

-- Get message by ID with sender/recipient details
-- Used in: GET /messages/{id}
SELECT 
    m.id, m.subject, m.content, m.is_read, m.read_at, 
    m.created_at, m.parent_message_id,
    sender_rp.first_name || ' ' || sender_rp.last_name as sender_name,
    sender_u.email as sender_email,
    recipient_rp.first_name || ' ' || recipient_rp.last_name as recipient_name,
    recipient_u.email as recipient_email
FROM messages m
LEFT JOIN users sender_u ON m.sender_id = sender_u.id
LEFT JOIN resident_profiles sender_rp ON sender_u.id = sender_rp.user_id
LEFT JOIN users recipient_u ON m.recipient_id = recipient_u.id
LEFT JOIN resident_profiles recipient_rp ON recipient_u.id = recipient_rp.user_id
WHERE m.id = $1;

-- Send message
-- Used in: POST /messages
INSERT INTO messages (sender_id, recipient_id, subject, content, parent_message_id)
VALUES ($1, $2, $3, $4, $5)
RETURNING id, subject, created_at;

-- Mark message as read
-- Used in: PATCH /messages/{id}/read
UPDATE messages
SET is_read = true, read_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
WHERE id = $1 AND recipient_id = $2
RETURNING id, is_read, read_at;

-- Delete message
-- Used in: DELETE /messages/{id}
DELETE FROM messages 
WHERE id = $1 AND (sender_id = $2 OR recipient_id = $2);

-- ============================================================================
-- AUDIT LOG QUERIES
-- ============================================================================

-- Create audit log entry
-- Used in: After any important action (login, create, update, delete)
INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details, ip_address, user_agent)
VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7)
RETURNING id, created_at;

-- Get audit logs for admin
-- Used in: GET /admin/audit-logs?user_id=&action=
SELECT 
    al.id, al.action, al.entity_type, al.entity_id, al.details,
    al.ip_address, al.created_at,
    u.email as user_email,
    rp.first_name || ' ' || rp.last_name as user_name
FROM audit_logs al
LEFT JOIN users u ON al.user_id = u.id
LEFT JOIN resident_profiles rp ON u.id = rp.user_id
WHERE 
    ($1 IS NULL OR al.user_id = $1)
    AND ($2 = '' OR al.action = $2)
ORDER BY al.created_at DESC
LIMIT $3 OFFSET $4;

-- Get user's own audit logs
-- Used in: GET /users/me/activity
SELECT id, action, entity_type, entity_id, details, ip_address, created_at
FROM audit_logs
WHERE user_id = $1
ORDER BY created_at DESC
LIMIT $2 OFFSET $3;

-- ============================================================================
-- ROLE QUERIES
-- ============================================================================

-- Get all roles
-- Used in: GET /admin/roles
SELECT id, name, description, created_at
FROM roles
ORDER BY id;

-- Get role by name
-- Used in: Internal helper for role validation
SELECT id, name, description
FROM roles
WHERE name = $1;

-- ============================================================================
-- STATISTICS QUERIES (for admin dashboard)
-- ============================================================================

-- Get total counts
SELECT 
    (SELECT COUNT(*) FROM users WHERE is_active = true) as active_users,
    (SELECT COUNT(*) FROM resident_profiles) as total_residents,
    (SELECT COUNT(*) FROM invitations WHERE status = 'pending' AND expires_at > NOW()) as pending_invitations,
    (SELECT COUNT(*) FROM announcements WHERE is_published = true) as published_announcements,
    (SELECT COUNT(*) FROM messages WHERE is_read = false) as unread_messages;

-- Get recent activity (for dashboard)
SELECT 
    al.action, al.entity_type, al.created_at,
    rp.first_name || ' ' || rp.last_name as user_name
FROM audit_logs al
LEFT JOIN users u ON al.user_id = u.id
LEFT JOIN resident_profiles rp ON u.id = rp.user_id
ORDER BY al.created_at DESC
LIMIT 10;

-- Get residents by floor distribution
SELECT floor_number, COUNT(*) as resident_count
FROM resident_profiles
WHERE floor_number IS NOT NULL
GROUP BY floor_number
ORDER BY floor_number;

-- ============================================================================
-- NOTES FOR BACKEND IMPLEMENTATION
-- ============================================================================

-- 1. Use parameterized queries ($1, $2, etc.) to prevent SQL injection
-- 2. All passwords must be bcrypt hashed before insertion
-- 3. Always update 'updated_at' timestamp on UPDATE operations
-- 4. Create audit log entries for: login, create, update, delete operations
-- 5. Verify user permissions before executing queries (RBAC)
-- 6. Handle NULL values appropriately using COALESCE for optional updates
-- 7. Use transactions for multi-step operations (e.g., create user + profile)
-- 8. Implement pagination with LIMIT and OFFSET for list queries
-- 9. For search, use ILIKE '%term%' for case-insensitive partial matching
-- 10. Check invitation expiry and status before acceptance

-- Connection via environment variables:
-- postgresql://{POSTGRES_USER}:{POSTGRES_PASSWORD}@localhost:{POSTGRES_PORT}/{POSTGRES_DB}
