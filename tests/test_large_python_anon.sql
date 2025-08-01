-- MySQL dump 10.13  Distrib 8.0.42, for Linux (x86_64)
--
-- Host: localhost    Database: test_large_python
-- ------------------------------------------------------
-- Server version	8.0.42-0ubuntu0.24.04.2

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
-- Table structure for table `test_large_python`
--

DROP TABLE IF EXISTS `test_large_python`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `test_large_python` (
  `id` int NOT NULL,
  `small_text` varchar(255) DEFAULT NULL,
  `boundary_32` text,
  `boundary_33` text,
  `large_yaml` text,
  `empty_field` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `test_large_python`
--

LOCK TABLES `test_large_python` WRITE;
/*!40000 ALTER TABLE `test_large_python` DISABLE KEYS */;
INSERT INTO `test_large_python` VALUES (1,'X','BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB','AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA','---
config:
  database:
    host: anonymized.example.com
    port: 5432
    username: anon_user
    password: REDACTED_PASSWORD_HASH_1234567890ABCDEF
    connection_pool:
      min_size: 5
      max_size: 20
      timeout: 30
  cache:
    type: redis
    host: cache-anonymized.example.com
    port: 6379
    ttl: 3600
  logging:
    level: INFO
    file: /var/log/anonymized/app.log
    max_size: 104857600
    backup_count: 10
  features:
    - feature_anonymized_1
    - feature_anonymized_2
    - feature_anonymized_3
    - feature_anonymized_4
    - feature_anonymized_5
  metadata:
    created_by: ANONYMIZED_USER
    created_at: 2025-01-01T00:00:00Z
    last_modified: 2025-01-01T00:00:00Z
    version: 1.0.0-anonymized
    environment: production-anonymized
---',''),(2,'X','BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB','AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA','---
config:
  database:
    host: anonymized.example.com
    port: 5432
    username: anon_user
    password: REDACTED_PASSWORD_HASH_1234567890ABCDEF
    connection_pool:
      min_size: 5
      max_size: 20
      timeout: 30
  cache:
    type: redis
    host: cache-anonymized.example.com
    port: 6379
    ttl: 3600
  logging:
    level: INFO
    file: /var/log/anonymized/app.log
    max_size: 104857600
    backup_count: 10
  features:
    - feature_anonymized_1
    - feature_anonymized_2
    - feature_anonymized_3
    - feature_anonymized_4
    - feature_anonymized_5
  metadata:
    created_by: ANONYMIZED_USER
    created_at: 2025-01-01T00:00:00Z
    last_modified: 2025-01-01T00:00:00Z
    version: 1.0.0-anonymized
    environment: production-anonymized
---','');
/*!40000 ALTER TABLE `test_large_python` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-07-25 21:44:03
