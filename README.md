================================================================================
================================================================================

PROJECT OVERVIEW:
Event-Management-amp-Ticketing-System
Handles event creation, ticket sales, and attendee management.

-----------------
A comprehensive database system for managing events, ticket sales, and 
attendee information. Includes automated booking processes, capacity 
management, revenue tracking, and security controls.

SYSTEM SPECIFICATIONS:
---------------------
- Database: MySQL 9.1.0
- Platform: WAMP Server (Windows)
- Database Name: EventDB
- Character Set: UTF-8
- Engine: InnoDB (transactional support)

DATABASE SCHEMA:
----------------
1. Venues - Event locations with capacity limits
2. Attendees - Customer information
3. Events - Event details and scheduling
4. Tickets - Ticket bookings and status
5. Payments - Payment transactions
6. SystemLogs - Audit trail for all operations

RELATIONSHIPS:
--------------
- Venues (1) → Events (Many)
- Events (1) → Tickets (Many)
- Attendees (1) → Tickets (Many)
- Tickets (1) → Payments (1)

KEY FEATURES:
-------------
Automated ticket booking with stored procedures
Overbooking prevention with triggers
Real-time revenue tracking with views
Comprehensive audit logging
Role-based security with 5 user types
Import/Export functionality
Multiple backup strategies
Data integrity enforcement

DELIVERABLES COMPLETED:
-----------------------
1. ERD + Normalized Schema
2. SQL Scripts (Tables & Sample Data)
3. CRUD Operations (10+ examples)
4. Subquery & JOIN Reports (12 reports)
5. Stored Procedures (4 procedures)
6. Overbooking Prevention Trigger (4 triggers)
7. Revenue Summary Views (3 views)
8. Import/Export Operations
9. Backup & Restore Process (4 backup types)
10. Security, Logs, and Documentation

STORED PROCEDURES:
------------------
1. BookTicket - Automated ticket booking with validation
2. CancelTicket - Cancel existing bookings
3. CheckEventAvailability - Check ticket availability
4. GetAttendeeBookings - View attendee purchase history

TRIGGERS:
---------
1. PreventOverbooking - Block bookings when venue is full
2. LogTicketCancellation - Auto-log cancellations
3. LogNewBooking - Auto-log new bookings
4. LogPaymentTransaction - Auto-log payments

VIEWS:
------
1. EventRevenueSummary - Revenue and capacity metrics per event
2. VenuePerformance - Aggregate venue statistics
3. AttendeeSpending - Customer spending analytics

SECURITY USERS:
---------------
1. root - Database Administrator (full access)
2. event_manager - Manage events and venues
3. ticket_agent - Book tickets and manage attendees
4. report_viewer - Read-only access to reports
5. app_user - Minimal access for applications

BACKUP STRATEGY:
----------------
- Full Backup: Weekly (Sunday)
- Differential: Daily (Monday-Saturday)
- Transaction Log: Continuous
- Incremental: Hourly (high-traffic periods)
- Retention: 7 days daily, 4 weeks weekly, 12 months monthly

TESTING PERFORMED:
------------------
CRUD operations on all tables
Stored procedure execution
Trigger functionality (overbooking prevention)
View queries and aggregations
User permission restrictions
Backup and restore process
Import/Export operations
System log generation

FUTURE ENHANCEMENTS:
--------------------
- Online payment gateway integration
- Email notification system
- Mobile application API
- Advanced analytics dashboard
- Multi-currency support
- Seat allocation system
- Waiting list management
- Promotional discount codes
- Customer loyalty program
- Social media integration

GROUP 10 (Event Management &amp; Ticketing System)
--------------------
Project Leaders: 
1.) Bondoc, Raver Wayne
2.) Señar, Edrian

Members:
3.) Abiera, Vincent
4.) Bautista, Steffanie
5.) Luna, Marc Laurence
6.) Timbas, Althea


Date: January 2026
Version: 1.0
Database: EventDB
MySQL Version: 9.1.0

================================================================================
================================================================================
