-- MySQL dump 10.13  Distrib 8.0.40, for Linux (x86_64)
--
-- Host: localhost    Database: test1
-- ------------------------------------------------------
-- Server version	8.0.40-0ubuntu0.24.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `lottypes`
--

DROP TABLE IF EXISTS `lottypes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `lottypes` (
  `int1` tinyint DEFAULT NULL,
  `int2` smallint DEFAULT NULL,
  `int3` mediumint DEFAULT NULL,
  `int4` int DEFAULT NULL,
  `int5` int DEFAULT NULL,
  `int6` bigint DEFAULT NULL,
  `dec1` decimal(5,2) DEFAULT NULL,
  `float1` float DEFAULT NULL,
  `double1` double DEFAULT NULL,
  `datetime1` datetime DEFAULT NULL,
  `date1` date DEFAULT NULL,
  `timestamp1` timestamp NULL DEFAULT NULL,
  `year1` year NOT NULL,
  `char1` char(1) DEFAULT NULL,
  `char2` varchar(50) DEFAULT NULL,
  `binary1` binary(50) DEFAULT NULL,
  `binary2` varbinary(50) DEFAULT NULL,
  `blob1` blob,
  `blob2` tinyblob,
  `blob3` mediumblob,
  `blog4` longblob,
  `text1` text,
  `text2` tinytext,
  `text3` mediumtext,
  `text4` longtext,
  `enum1` enum('small','meduim','large') DEFAULT NULL,
  `json1` json DEFAULT NULL,
  `set1` set('C','Rust','Haskell') DEFAULT NULL,
  `point1` point /*!80003 SRID 0 */ DEFAULT NULL,
  `geometry1` geometry DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lottypes`
--

LOCK TABLES `lottypes` WRITE;
/*!40000 ALTER TABLE `lottypes` DISABLE KEYS */;
INSERT INTO `lottypes` VALUES (1,2,3,4,5,6,5.20,1e17,2e16,'2021-01-20 15:00:00','2021-01-20','2021-02-14 15:41:45',2025,'a','b',_binary '\0\0\0x�3\0\02\02\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0',_binary '\0\0\0x�3\0\03\03',_binary '\0\0\0x�3\0\04\04',_binary '\0\0\0x�3\0\05\05',_binary '\0\0\0x�3\0\06\06',_binary '\0\0\0x�3\0\07\07','text1','text2','text3','text4','small','{\"key\": \"value\"}','C,Haskell',_binary '\0\0\0\0\0\0\0\0\0\0\0\0\0\�?\0\0\0\0\0\0\�?',_binary '\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0@\0\0\0\0\0\0\0@\0\0\0\0\0\0@\0\0\0\0\0\0\0@\0\0\0\0\0\0@\0\0\0\0\0\0\0\0\0\0\0\0\0\0@\0\0\0\0\0\0\0\0\0\0\0\0\0\0@');
/*!40000 ALTER TABLE `lottypes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notanontable`
--

DROP TABLE IF EXISTS `notanontable`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notanontable` (
  `id` int DEFAULT NULL,
  `email` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notanontable`
--

LOCK TABLES `notanontable` WRITE;
/*!40000 ALTER TABLE `notanontable` DISABLE KEYS */;
INSERT INTO `notanontable` VALUES (1,'me@gmail.com');
/*!40000 ALTER TABLE `notanontable` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `table to truncate`
--

DROP TABLE IF EXISTS `table to truncate`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `table to truncate` (
  `a` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `table to truncate`
--

LOCK TABLES `table to truncate` WRITE;
/*!40000 ALTER TABLE `table to truncate` DISABLE KEYS */;
INSERT INTO `table to truncate` VALUES (555),(666);
/*!40000 ALTER TABLE `table to truncate` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `tata`
--

DROP TABLE IF EXISTS `tata`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tata` (
  `id` int DEFAULT NULL,
  `email` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tata`
--

LOCK TABLES `tata` WRITE;
/*!40000 ALTER TABLE `tata` DISABLE KEYS */;
INSERT INTO `tata` VALUES (-1,'pp@mydomain.com');
/*!40000 ALTER TABLE `tata` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `test_with_column_names`
--

DROP TABLE IF EXISTS `test_with_column_names`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `test_with_column_names` (
  `a` int unsigned DEFAULT NULL,
  `b` int unsigned DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `test_with_column_names`
--

LOCK TABLES `test_with_column_names` WRITE;
/*!40000 ALTER TABLE `test_with_column_names` DISABLE KEYS */;
INSERT INTO `test_with_column_names` VALUES (1,1),(1,1);
/*!40000 ALTER TABLE `test_with_column_names` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `the_blobs`
--

DROP TABLE IF EXISTS `the_blobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `the_blobs` (
  `blob1` blob,
  `blob2` tinyblob,
  `blob3` mediumblob,
  `blog4` longblob
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `the_blobs`
--

LOCK TABLES `the_blobs` WRITE;
/*!40000 ALTER TABLE `the_blobs` DISABLE KEYS */;
INSERT INTO `the_blobs` VALUES (_binary 'hello',_binary 'hello',_binary 'hello',_binary 'hello'),(_binary 'a',_binary 'b',_binary 'c',_binary 'd');
/*!40000 ALTER TABLE `the_blobs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `toto`
--

DROP TABLE IF EXISTS `toto`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `toto` (
  `a` int DEFAULT NULL,
  `b` text,
  `c` text,
  `name` char(30) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `toto`
--

LOCK TABLES `toto` WRITE;
/*!40000 ALTER TABLE `toto` DISABLE KEYS */;
INSERT INTO `toto` VALUES (6128,'cpc','ppomes2','otherval1'),(2,'àçê','simon','otherval2'),(464,'cpc','ppomes','otherval3'),(2,'àçê','brtvl','otherval4');
/*!40000 ALTER TABLE `toto` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-01-06 16:27:35
