-- MySQL dump 10.13  Distrib 8.0.23, for Linux (x86_64)
--
-- Host: localhost    Database: pp
-- ------------------------------------------------------
-- Server version	8.0.23-0ubuntu0.20.10.1

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
  `json1` json DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lottypes`
--

LOCK TABLES `lottypes` WRITE;
/*!40000 ALTER TABLE `lottypes` DISABLE KEYS */;
INSERT INTO `lottypes` VALUES (1,2,3,4,5,6,5.20,1e17,2e16,'2021-01-20 15:00:00','2021-01-20','2021-02-14 15:41:45','a','b',_binary '\0\0\0xœ3\0\02\02\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0',_binary '\0\0\0xœ3\0\03\03',_binary '\0\0\0xœ3\0\04\04',_binary '\0\0\0xœ3\0\05\05',_binary '\0\0\0xœ3\0\06\06',_binary '\0\0\0xœ3\0\07\07','text1','text2','text3','text4','small','{\"key\": \"value\"}');
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
INSERT INTO `toto` VALUES (6128,'cpc','ppomes2','otherval1'),(2,'Ã Ã§Ãª','simon','otherval2'),(464,'cpc','ppomes'),(2,'Ã Ã§Ãª','brtvl','otherval3');
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

-- Dump completed on 2021-02-20 15:49:47
