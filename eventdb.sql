-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1:3306
-- Generation Time: Jan 07, 2026 at 07:19 AM
-- Server version: 9.1.0
-- PHP Version: 8.3.14

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `eventdb`
--

DELIMITER $$
--
-- Procedures
--
DROP PROCEDURE IF EXISTS `BookTicket`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `BookTicket` (IN `p_EventID` INT, IN `p_AttendeeID` INT, IN `p_PaymentAmount` DECIMAL(10,2), IN `p_PaymentMethod` VARCHAR(50))   BEGIN
    DECLARE v_TicketID INT;
    DECLARE v_VenueCapacity INT;
    DECLARE v_TicketsSold INT;
    DECLARE v_EventExists INT;
    DECLARE v_AttendeeExists INT;
    DECLARE v_EventName VARCHAR(100);
    DECLARE v_AttendeeName VARCHAR(100);
    DECLARE v_ErrorMessage VARCHAR(255);
    
    SET v_ErrorMessage = NULL;

    SELECT COUNT(*), IFNULL(EventName, '') 
    INTO v_EventExists, v_EventName
    FROM Events
    WHERE EventID = p_EventID;
    
    IF v_EventExists = 0 THEN
        SELECT 'ERROR: Event does not exist.' AS Status;
        SET v_ErrorMessage = 'Event does not exist';
    END IF;
    
    IF v_ErrorMessage IS NULL THEN
        SELECT COUNT(*), IFNULL(CONCAT(FirstName, ' ', LastName), '') 
        INTO v_AttendeeExists, v_AttendeeName
        FROM Attendees
        WHERE AttendeeID = p_AttendeeID;
        
        IF v_AttendeeExists = 0 THEN
            SELECT 'ERROR: Attendee does not exist.' AS Status;
            SET v_ErrorMessage = 'Attendee does not exist';
        END IF;
    END IF;
    
    IF v_ErrorMessage IS NULL THEN
        SELECT v.Capacity INTO v_VenueCapacity
        FROM Events e
        JOIN Venues v ON e.VenueID = v.VenueID
        WHERE e.EventID = p_EventID;
        
        -- Count confirmed tickets for this event
        SELECT COUNT(*) INTO v_TicketsSold
        FROM Tickets
        WHERE EventID = p_EventID AND Status = 'Confirmed';
        
        IF v_TicketsSold >= v_VenueCapacity THEN
            SELECT 'ERROR: Event is fully booked. No tickets available.' AS Status;
            SET v_ErrorMessage = 'Event fully booked';
        END IF;
    END IF;

    IF v_ErrorMessage IS NULL THEN
        START TRANSACTION;
        
        INSERT INTO Tickets (EventID, AttendeeID, PurchaseDate, Status)
        VALUES (p_EventID, p_AttendeeID, NOW(), 'Confirmed');
        
        SET v_TicketID = LAST_INSERT_ID();
        
        INSERT INTO Payments (TicketID, Amount, PaymentMethod, PaymentDate)
        VALUES (v_TicketID, p_PaymentAmount, p_PaymentMethod, NOW());
        
        COMMIT;

        SELECT 
            'SUCCESS: Booking completed successfully!' AS Status,
            v_TicketID AS TicketID,
            v_EventName AS EventName,
            v_AttendeeName AS AttendeeName,
            p_PaymentAmount AS AmountPaid,
            p_PaymentMethod AS PaymentMethod,
            NOW() AS BookingTime;
    END IF;
    
END$$

DROP PROCEDURE IF EXISTS `CancelTicket`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `CancelTicket` (IN `p_TicketID` INT)   BEGIN
    DECLARE v_TicketExists INT;
    DECLARE v_CurrentStatus VARCHAR(20);
    
    SELECT COUNT(*), IFNULL(Status, '') 
    INTO v_TicketExists, v_CurrentStatus
    FROM Tickets
    WHERE TicketID = p_TicketID;
    
    IF v_TicketExists = 0 THEN
        SELECT 'ERROR: Ticket does not exist.' AS Status;
    ELSEIF v_CurrentStatus = 'Cancelled' THEN
        SELECT 'ERROR: Ticket is already cancelled.' AS Status;
    ELSE
        UPDATE Tickets
        SET Status = 'Cancelled'
        WHERE TicketID = p_TicketID;
        
        SELECT 
            'SUCCESS: Ticket cancelled successfully.' AS Status,
            p_TicketID AS TicketID;
    END IF;
    
END$$

DROP PROCEDURE IF EXISTS `CheckEventAvailability`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `CheckEventAvailability` (IN `p_EventID` INT)   BEGIN
    DECLARE v_EventExists INT;
    
    SELECT COUNT(*) INTO v_EventExists
    FROM Events
    WHERE EventID = p_EventID;
    
    IF v_EventExists = 0 THEN
        SELECT 'ERROR: Event does not exist.' AS Status;
    ELSE
        SELECT 
            e.EventID,
            e.EventName,
            e.EventDate,
            v.VenueName,
            v.Capacity AS TotalCapacity,
            COUNT(t.TicketID) AS TicketsSold,
            (v.Capacity - COUNT(t.TicketID)) AS AvailableTickets,
            e.BasePrice,
            CASE 
                WHEN COUNT(t.TicketID) >= v.Capacity THEN 'SOLD OUT'
                WHEN COUNT(t.TicketID) >= (v.Capacity * 0.8) THEN 'ALMOST FULL'
                ELSE 'AVAILABLE'
            END AS AvailabilityStatus
        FROM Events e
        JOIN Venues v ON e.VenueID = v.VenueID
        LEFT JOIN Tickets t ON e.EventID = t.EventID AND t.Status = 'Confirmed'
        WHERE e.EventID = p_EventID
        GROUP BY e.EventID, e.EventName, e.EventDate, v.VenueName, v.Capacity, e.BasePrice;
    END IF;
    
END$$

DROP PROCEDURE IF EXISTS `GetAttendeeBookings`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `GetAttendeeBookings` (IN `p_AttendeeID` INT)   BEGIN
    DECLARE v_AttendeeExists INT;
    
    SELECT COUNT(*) INTO v_AttendeeExists
    FROM Attendees
    WHERE AttendeeID = p_AttendeeID;
    
    IF v_AttendeeExists = 0 THEN
        SELECT 'ERROR: Attendee does not exist.' AS Status;
    ELSE
        SELECT 
            t.TicketID,
            e.EventName,
            e.EventDate,
            v.VenueName,
            t.PurchaseDate,
            t.Status,
            IFNULL(p.Amount, 0) AS AmountPaid,
            IFNULL(p.PaymentMethod, 'N/A') AS PaymentMethod
        FROM Tickets t
        JOIN Events e ON t.EventID = e.EventID
        JOIN Venues v ON e.VenueID = v.VenueID
        LEFT JOIN Payments p ON t.TicketID = p.TicketID
        WHERE t.AttendeeID = p_AttendeeID
        ORDER BY e.EventDate DESC;
    END IF;
    
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `attendees`
--

DROP TABLE IF EXISTS `attendees`;
CREATE TABLE IF NOT EXISTS `attendees` (
  `AttendeeID` int NOT NULL AUTO_INCREMENT,
  `FirstName` varchar(50) DEFAULT NULL,
  `LastName` varchar(50) DEFAULT NULL,
  `Email` varchar(100) DEFAULT NULL,
  `Phone` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`AttendeeID`),
  UNIQUE KEY `Email` (`Email`)
) ENGINE=MyISAM AUTO_INCREMENT=14 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `attendees`
--

INSERT INTO `attendees` (`AttendeeID`, `FirstName`, `LastName`, `Email`, `Phone`) VALUES
(1, 'John', 'Doe', 'john.doe@email.com', '0917-999-8888'),
(2, 'Jane', 'Smith', 'jane.smith@email.com', '0918-234-5678'),
(3, 'Michael', 'Johnson', 'michael.j@email.com', '0919-345-6789'),
(4, 'Emily', 'Williams', 'emily.w@email.com', '0920-456-7890'),
(5, 'David', 'Brown', 'david.brown@email.com', '0921-567-8901'),
(6, 'Sarah', 'Jones', 'sarah.jones@email.com', '0922-678-9012'),
(7, 'Robert', 'Garcia', 'robert.g@email.com', '0923-789-0123'),
(8, 'Lisa', 'Martinez', 'lisa.m@email.com', '0924-890-1234'),
(9, 'James', 'Rodriguez', 'james.r@email.com', '0925-901-2345'),
(10, 'Maria', 'Hernandez', 'maria.h@email.com', '0926-012-3456'),
(11, 'Carlos', 'Santos', 'carlos.santos@email.com', '0927-111-2222');

-- --------------------------------------------------------

--
-- Stand-in structure for view `attendeespending`
-- (See below for the actual view)
--
DROP VIEW IF EXISTS `attendeespending`;
CREATE TABLE IF NOT EXISTS `attendeespending` (
`AttendeeFullName` varchar(101)
,`AttendeeID` int
,`AverageSpendPerTicket` decimal(14,6)
,`Email` varchar(100)
,`LastPurchaseDate` datetime
,`Phone` varchar(20)
,`TotalSpent` decimal(32,2)
,`TotalTicketsPurchased` bigint
,`UniqueEventsAttended` bigint
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `eventrevenuesummary`
-- (See below for the actual view)
--
DROP VIEW IF EXISTS `eventrevenuesummary`;
CREATE TABLE IF NOT EXISTS `eventrevenuesummary` (
`AverageTicketPrice` decimal(14,6)
,`BasePrice` decimal(10,2)
,`CancelledTickets` bigint
,`CapacityFillPercentage` decimal(26,2)
,`ConfirmedTickets` bigint
,`EventDate` datetime
,`EventID` int
,`EventName` varchar(100)
,`Location` varchar(255)
,`RemainingCapacity` bigint
,`TotalRevenue` decimal(32,2)
,`TotalTickets` bigint
,`VenueCapacity` int
,`VenueID` int
,`VenueName` varchar(100)
);

-- --------------------------------------------------------

--
-- Table structure for table `events`
--

DROP TABLE IF EXISTS `events`;
CREATE TABLE IF NOT EXISTS `events` (
  `EventID` int NOT NULL AUTO_INCREMENT,
  `EventName` varchar(100) NOT NULL,
  `EventDate` datetime NOT NULL,
  `VenueID` int DEFAULT NULL,
  `BasePrice` decimal(10,2) DEFAULT NULL,
  PRIMARY KEY (`EventID`),
  KEY `VenueID` (`VenueID`)
) ENGINE=MyISAM AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `events`
--

INSERT INTO `events` (`EventID`, `EventName`, `EventDate`, `VenueID`, `BasePrice`) VALUES
(1, 'Tech Summit 2025', '2025-12-02 10:00:00', 1, 90.00),
(2, 'Music Fest', '2025-12-15 18:00:00', 2, 120.00),
(3, 'Business Leadership Conference', '2025-11-20 08:00:00', 3, 150.00),
(4, 'Summer Beach Concert', '2026-01-10 17:00:00', 4, 80.00),
(5, 'Mountain Retreat Workshop', '2025-11-25 10:00:00', 2, 120.00),
(6, 'Holiday Gala Night', '2025-12-24 20:00:00', 3, 200.00);

-- --------------------------------------------------------

--
-- Table structure for table `payments`
--

DROP TABLE IF EXISTS `payments`;
CREATE TABLE IF NOT EXISTS `payments` (
  `PaymentID` int NOT NULL AUTO_INCREMENT,
  `TicketID` int DEFAULT NULL,
  `Amount` decimal(10,2) DEFAULT NULL,
  `PaymentMethod` varchar(50) DEFAULT NULL,
  `PaymentDate` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`PaymentID`),
  KEY `TicketID` (`TicketID`)
) ENGINE=MyISAM AUTO_INCREMENT=17 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `payments`
--

INSERT INTO `payments` (`PaymentID`, `TicketID`, `Amount`, `PaymentMethod`, `PaymentDate`) VALUES
(15, 17, 50.00, 'Credit Card', '2026-01-06 10:41:09'),
(2, 2, 100.00, 'PayPal', '2026-01-05 14:07:44'),
(3, 3, 100.00, 'Debit Card', '2026-01-05 14:07:44'),
(4, 5, 50.00, 'Cash', '2026-01-05 14:08:09'),
(5, 6, 50.00, 'Credit Card', '2026-01-05 14:08:09'),
(6, 7, 50.00, 'PayPal', '2026-01-05 14:08:09'),
(7, 8, 50.00, 'Debit Card', '2026-01-05 14:08:09'),
(8, 9, 150.00, 'Credit Card', '2026-01-05 14:08:26'),
(9, 10, 150.00, 'Bank Transfer', '2026-01-05 14:08:26'),
(10, 11, 150.00, 'Credit Card', '2026-01-05 14:08:26'),
(11, 12, 80.00, 'Credit Card', '2026-01-05 14:08:45'),
(12, 13, 80.00, 'Debit Card', '2026-01-05 14:08:45'),
(13, 14, 120.00, 'Credit Card', '2026-01-05 14:08:57'),
(14, 0, 100.00, 'Credit Card', '2026-01-05 14:25:31'),
(16, 25, 50.00, 'Cash', '2026-01-06 16:22:50');

--
-- Triggers `payments`
--
DROP TRIGGER IF EXISTS `LogPaymentTransaction`;
DELIMITER $$
CREATE TRIGGER `LogPaymentTransaction` AFTER INSERT ON `payments` FOR EACH ROW BEGIN
    INSERT INTO SystemLogs (LogType, LogMessage)
    VALUES (
        'Payment',
        CONCAT('Payment ID ', NEW.PaymentID,
               ' of ₱', NEW.Amount,
               ' via ', NEW.PaymentMethod,
               ' for Ticket ID ', NEW.TicketID,
               ' processed at ', NEW.PaymentDate)
    );
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `systemlogs`
--

DROP TABLE IF EXISTS `systemlogs`;
CREATE TABLE IF NOT EXISTS `systemlogs` (
  `LogID` int NOT NULL AUTO_INCREMENT,
  `LogType` enum('Booking','Cancellation','Payment','System','Security') DEFAULT 'System',
  `LogMessage` text NOT NULL,
  `UserType` varchar(50) DEFAULT NULL,
  `LogDate` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`LogID`),
  KEY `idx_log_type` (`LogType`),
  KEY `idx_log_date` (`LogDate`)
) ENGINE=MyISAM AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `systemlogs`
--

INSERT INTO `systemlogs` (`LogID`, `LogType`, `LogMessage`, `UserType`, `LogDate`) VALUES
(1, 'Booking', 'New ticket ID 21 booked for Event ID 4 by Attendee ID 6 at 2026-01-06 10:51:22', NULL, '2026-01-06 02:51:22'),
(2, 'Booking', 'New ticket ID 22 booked for Event ID 2 by Attendee ID 9 at 2026-01-06 10:51:42', NULL, '2026-01-06 02:51:42'),
(3, 'Booking', 'New ticket ID 23 booked for Event ID 2 by Attendee ID 10 at 2026-01-06 10:51:42', NULL, '2026-01-06 02:51:42'),
(4, 'Booking', 'New ticket ID 24 booked for Event ID 2 by Attendee ID 8 at 2026-01-06 10:52:27', NULL, '2026-01-06 02:52:27'),
(5, 'Booking', 'New ticket ID 25 booked for Event ID 2 by Attendee ID 5 at 2026-01-06 16:22:50', NULL, '2026-01-06 08:22:50'),
(6, 'Payment', 'Payment ID 16 of ₱50.00 via Cash for Ticket ID 25 processed at 2026-01-06 16:22:50', NULL, '2026-01-06 08:22:50'),
(7, 'Security', 'Database users created and permissions configured', 'Administrator', '2026-01-06 08:27:03'),
(8, 'Security', 'Security demonstration completed successfully', 'Administrator', '2026-01-06 08:27:10');

-- --------------------------------------------------------

--
-- Table structure for table `tickets`
--

DROP TABLE IF EXISTS `tickets`;
CREATE TABLE IF NOT EXISTS `tickets` (
  `TicketID` int NOT NULL AUTO_INCREMENT,
  `EventID` int DEFAULT NULL,
  `AttendeeID` int DEFAULT NULL,
  `PurchaseDate` datetime DEFAULT CURRENT_TIMESTAMP,
  `Status` enum('Confirmed','Cancelled') DEFAULT 'Confirmed',
  PRIMARY KEY (`TicketID`),
  KEY `EventID` (`EventID`),
  KEY `AttendeeID` (`AttendeeID`)
) ENGINE=MyISAM AUTO_INCREMENT=26 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `tickets`
--

INSERT INTO `tickets` (`TicketID`, `EventID`, `AttendeeID`, `PurchaseDate`, `Status`) VALUES
(1, 1, 1, '2025-11-15 10:30:00', 'Cancelled'),
(2, 1, 2, '2025-11-16 14:20:00', 'Confirmed'),
(3, 1, 3, '2025-11-17 09:15:00', 'Confirmed'),
(17, 2, 3, '2026-01-06 10:41:09', 'Confirmed'),
(5, 2, 5, '2025-11-10 12:00:00', 'Cancelled'),
(6, 2, 6, '2025-11-11 15:30:00', 'Confirmed'),
(7, 2, 7, '2025-11-12 10:00:00', 'Confirmed'),
(8, 2, 8, '2025-11-13 14:20:00', 'Confirmed'),
(9, 3, 9, '2025-11-01 08:00:00', 'Confirmed'),
(10, 3, 10, '2025-11-02 09:30:00', 'Confirmed'),
(11, 3, 1, '2025-11-03 10:15:00', 'Confirmed'),
(12, 4, 2, '2025-12-20 09:00:00', 'Confirmed'),
(13, 4, 3, '2025-12-21 10:30:00', 'Confirmed'),
(14, 5, 4, '2025-11-10 08:30:00', 'Confirmed'),
(15, 5, 5, '2025-11-11 09:45:00', 'Cancelled'),
(16, 1, 1, '2026-01-05 14:24:44', 'Confirmed'),
(18, 4, 6, '2026-01-06 10:46:00', 'Confirmed'),
(19, 4, 6, '2026-01-06 10:46:20', 'Confirmed'),
(20, 4, 6, '2026-01-06 10:46:27', 'Confirmed'),
(21, 4, 6, '2026-01-06 10:51:22', 'Confirmed'),
(22, 2, 9, '2026-01-06 10:51:42', 'Confirmed'),
(23, 2, 10, '2026-01-06 10:51:42', 'Confirmed'),
(24, 2, 8, '2026-01-06 10:52:27', 'Confirmed'),
(25, 2, 5, '2026-01-06 16:22:50', 'Confirmed');

--
-- Triggers `tickets`
--
DROP TRIGGER IF EXISTS `LogNewBooking`;
DELIMITER $$
CREATE TRIGGER `LogNewBooking` AFTER INSERT ON `tickets` FOR EACH ROW BEGIN
    INSERT INTO SystemLogs (LogType, LogMessage)
    VALUES (
        'Booking',
        CONCAT('New ticket ID ', NEW.TicketID, 
               ' booked for Event ID ', NEW.EventID,
               ' by Attendee ID ', NEW.AttendeeID,
               ' at ', NEW.PurchaseDate)
    );
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `LogTicketCancellation`;
DELIMITER $$
CREATE TRIGGER `LogTicketCancellation` AFTER UPDATE ON `tickets` FOR EACH ROW BEGIN
    IF NEW.Status = 'Cancelled' AND OLD.Status != 'Cancelled' THEN
        INSERT INTO SystemLogs (LogType, LogMessage)
        VALUES (
            'Cancellation',
            CONCAT('Ticket ID ', NEW.TicketID, 
                   ' for Event ID ', NEW.EventID, 
                   ' was cancelled at ', NOW())
        );
    END IF;
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `PreventOverbooking`;
DELIMITER $$
CREATE TRIGGER `PreventOverbooking` BEFORE INSERT ON `tickets` FOR EACH ROW BEGIN
    DECLARE v_CurrentTicketCount INT;
    DECLARE v_VenueCapacity INT;
    
    -- Get current confirmed ticket count for the event
    SELECT COUNT(*) INTO v_CurrentTicketCount
    FROM Tickets
    WHERE EventID = NEW.EventID 
      AND Status = 'Confirmed';
    
    -- Get venue capacity for this event
    SELECT v.Capacity INTO v_VenueCapacity
    FROM Events e
    JOIN Venues v ON e.VenueID = v.VenueID
    WHERE e.EventID = NEW.EventID;
    
    -- Check if booking would exceed capacity
    IF v_CurrentTicketCount >= v_VenueCapacity THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ERROR: Event is fully booked. Cannot add more tickets.';
    END IF;
    
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Stand-in structure for view `venueperformance`
-- (See below for the actual view)
--
DROP VIEW IF EXISTS `venueperformance`;
CREATE TABLE IF NOT EXISTS `venueperformance` (
`AverageRevenuePerEvent` decimal(33,2)
,`AverageTicketPrice` decimal(14,6)
,`Capacity` int
,`Location` varchar(255)
,`TotalEventsHosted` bigint
,`TotalRevenue` decimal(32,2)
,`TotalTicketsSold` bigint
,`VenueID` int
,`VenueName` varchar(100)
);

-- --------------------------------------------------------

--
-- Table structure for table `venues`
--

DROP TABLE IF EXISTS `venues`;
CREATE TABLE IF NOT EXISTS `venues` (
  `VenueID` int NOT NULL AUTO_INCREMENT,
  `VenueName` varchar(100) NOT NULL,
  `Capacity` int NOT NULL,
  `Location` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`VenueID`)
) ENGINE=MyISAM AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `venues`
--

INSERT INTO `venues` (`VenueID`, `VenueName`, `Capacity`, `Location`) VALUES
(1, 'Grand Hall', 50, 'Downtown Manila'),
(2, 'Open Air Park', 200, 'Uptown Quezon City'),
(3, 'City Convention Center', 500, 'Makati Business District'),
(4, 'Sunset Beach Arena', 1000, 'Coastal Bay Area'),
(5, 'Mountain View Lodge', 80, 'Tagaytay Highlands');

-- --------------------------------------------------------

--
-- Structure for view `attendeespending`
--
DROP TABLE IF EXISTS `attendeespending`;

DROP VIEW IF EXISTS `attendeespending`;
CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `attendeespending`  AS SELECT `a`.`AttendeeID` AS `AttendeeID`, concat(`a`.`FirstName`,' ',`a`.`LastName`) AS `AttendeeFullName`, `a`.`Email` AS `Email`, `a`.`Phone` AS `Phone`, count(`t`.`TicketID`) AS `TotalTicketsPurchased`, count(distinct `t`.`EventID`) AS `UniqueEventsAttended`, ifnull(sum(`p`.`Amount`),0) AS `TotalSpent`, ifnull(avg(`p`.`Amount`),0) AS `AverageSpendPerTicket`, max(`t`.`PurchaseDate`) AS `LastPurchaseDate` FROM ((`attendees` `a` left join `tickets` `t` on(((`a`.`AttendeeID` = `t`.`AttendeeID`) and (`t`.`Status` = 'Confirmed')))) left join `payments` `p` on((`t`.`TicketID` = `p`.`TicketID`))) GROUP BY `a`.`AttendeeID`, `a`.`FirstName`, `a`.`LastName`, `a`.`Email`, `a`.`Phone` ;

-- --------------------------------------------------------

--
-- Structure for view `eventrevenuesummary`
--
DROP TABLE IF EXISTS `eventrevenuesummary`;

DROP VIEW IF EXISTS `eventrevenuesummary`;
CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `eventrevenuesummary`  AS SELECT `e`.`EventID` AS `EventID`, `e`.`EventName` AS `EventName`, `e`.`EventDate` AS `EventDate`, `v`.`VenueID` AS `VenueID`, `v`.`VenueName` AS `VenueName`, `v`.`Location` AS `Location`, `v`.`Capacity` AS `VenueCapacity`, `e`.`BasePrice` AS `BasePrice`, count(`t`.`TicketID`) AS `TotalTickets`, count((case when (`t`.`Status` = 'Confirmed') then 1 end)) AS `ConfirmedTickets`, count((case when (`t`.`Status` = 'Cancelled') then 1 end)) AS `CancelledTickets`, ifnull(sum((case when (`t`.`Status` = 'Confirmed') then `p`.`Amount` else 0 end)),0) AS `TotalRevenue`, ifnull(avg((case when (`t`.`Status` = 'Confirmed') then `p`.`Amount` end)),0) AS `AverageTicketPrice`, (`v`.`Capacity` - count((case when (`t`.`Status` = 'Confirmed') then 1 end))) AS `RemainingCapacity`, round(((count((case when (`t`.`Status` = 'Confirmed') then 1 end)) / `v`.`Capacity`) * 100),2) AS `CapacityFillPercentage` FROM (((`events` `e` join `venues` `v` on((`e`.`VenueID` = `v`.`VenueID`))) left join `tickets` `t` on((`e`.`EventID` = `t`.`EventID`))) left join `payments` `p` on((`t`.`TicketID` = `p`.`TicketID`))) GROUP BY `e`.`EventID`, `e`.`EventName`, `e`.`EventDate`, `v`.`VenueID`, `v`.`VenueName`, `v`.`Location`, `v`.`Capacity`, `e`.`BasePrice` ;

-- --------------------------------------------------------

--
-- Structure for view `venueperformance`
--
DROP TABLE IF EXISTS `venueperformance`;

DROP VIEW IF EXISTS `venueperformance`;
CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `venueperformance`  AS SELECT `v`.`VenueID` AS `VenueID`, `v`.`VenueName` AS `VenueName`, `v`.`Location` AS `Location`, `v`.`Capacity` AS `Capacity`, count(distinct `e`.`EventID`) AS `TotalEventsHosted`, count(`t`.`TicketID`) AS `TotalTicketsSold`, ifnull(sum(`p`.`Amount`),0) AS `TotalRevenue`, ifnull(avg(`p`.`Amount`),0) AS `AverageTicketPrice`, round((ifnull(sum(`p`.`Amount`),0) / nullif(count(distinct `e`.`EventID`),0)),2) AS `AverageRevenuePerEvent` FROM (((`venues` `v` left join `events` `e` on((`v`.`VenueID` = `e`.`VenueID`))) left join `tickets` `t` on(((`e`.`EventID` = `t`.`EventID`) and (`t`.`Status` = 'Confirmed')))) left join `payments` `p` on((`t`.`TicketID` = `p`.`TicketID`))) GROUP BY `v`.`VenueID`, `v`.`VenueName`, `v`.`Location`, `v`.`Capacity` ;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
