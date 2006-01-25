-- MySQL dump 10.10
--
-- Host: localhost    Database: preserv
-- ------------------------------------------------------
-- Server version	5.0.16-standard

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `license`
--

DROP TABLE IF EXISTS `license`;
CREATE TABLE `license` (
  `licenseid` varchar(255) NOT NULL,
  `rev_number` int(11) default NULL,
  `url` varchar(255) default NULL,
  PRIMARY KEY  (`licenseid`),
  KEY `rev_number` (`rev_number`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `license__index_grep`
--

DROP TABLE IF EXISTS `license__index_grep`;
CREATE TABLE `license__index_grep` (
  `licenseid` varchar(255) default NULL,
  `fieldname` varchar(255) default NULL,
  `grepstring` varchar(255) default NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `license__rindex`
--

DROP TABLE IF EXISTS `license__rindex`;
CREATE TABLE `license__rindex` (
  `licenseid` varchar(255) default NULL,
  `field` varchar(255) default NULL,
  `word` varchar(255) default NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `license_name`
--

DROP TABLE IF EXISTS `license_name`;
CREATE TABLE `license_name` (
  `licenseid` varchar(255) default NULL,
  `lang` varchar(16) default NULL,
  `name` varchar(255) default NULL,
  KEY `lang` (`lang`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `license__index`
--

DROP TABLE IF EXISTS `license__index`;
CREATE TABLE `license__index` (
  `fieldword` varchar(255) default NULL,
  `pos` int(11) default NULL,
  `ids` text,
  KEY `pos` (`pos`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `license__ordervalues_en`
--

DROP TABLE IF EXISTS `license__ordervalues_en`;
CREATE TABLE `license__ordervalues_en` (
  `licenseid` varchar(255) NOT NULL,
  `rev_number` text,
  `url` text,
  `name` text,
  PRIMARY KEY  (`licenseid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- New license field in Document
--

ALTER TABLE `document` ADD `license` VARCHAR(255) AFTER `security`;

/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

