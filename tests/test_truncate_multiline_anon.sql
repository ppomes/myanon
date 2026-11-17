-- MariaDB dump 10.19  Distrib 11.4.3-MariaDB, for Linux (x86_64)
--
-- Host: localhost    Database: test_default
-- ------------------------------------------------------

--
-- Table structure for table `sessions`
--

DROP TABLE IF EXISTS `sessions`;
CREATE TABLE `sessions` (
  `id` int(11) NOT NULL,
  `v` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `sessions`
--

LOCK TABLES `sessions` WRITE;
/*!40000 ALTER TABLE `sessions` DISABLE KEYS */;

/*!40000 ALTER TABLE `sessions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `unknown_people`
--

DROP TABLE IF EXISTS `unknown_people`;
CREATE TABLE `unknown_people` (
  `id` int(11) NOT NULL,
  `v` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `unknown_people`
--

LOCK TABLES `unknown_people` WRITE;
/*!40000 ALTER TABLE `unknown_people` DISABLE KEYS */;

/*!40000 ALTER TABLE `unknown_people` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `café_clients`
--

DROP TABLE IF EXISTS `café_clients`;
CREATE TABLE `café_clients` (
  `id` int(11) NOT NULL,
  `v` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `café_clients`
--

LOCK TABLES `café_clients` WRITE;
/*!40000 ALTER TABLE `café_clients` DISABLE KEYS */;

/*!40000 ALTER TABLE `café_clients` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `odd'name`
--

DROP TABLE IF EXISTS `odd'name`;
CREATE TABLE `odd'name` (
  `id` int(11) NOT NULL,
  `n` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `odd'name`
--

LOCK TABLES `odd'name` WRITE;
/*!40000 ALTER TABLE `odd'name` DISABLE KEYS */;

/*!40000 ALTER TABLE `odd'name` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `countries`
--

DROP TABLE IF EXISTS `countries`;
CREATE TABLE `countries` (
  `id` int(11) NOT NULL,
  `v` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `countries`
--

LOCK TABLES `countries` WRITE;
/*!40000 ALTER TABLE `countries` DISABLE KEYS */;
INSERT INTO `countries` VALUES
(1,'France; Europe'),
(2,'Japan');
/*!40000 ALTER TABLE `countries` ENABLE KEYS */;
UNLOCK TABLES;

-- Dump completed on 2026-11-17 12:00:00
