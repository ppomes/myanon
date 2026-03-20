DROP TABLE IF EXISTS `truncate_semicolon_case`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `truncate_semicolon_case` (
  `id` int NOT NULL AUTO_INCREMENT,
  `note` varchar(255) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `truncate_semicolon_case`
--

LOCK TABLES `truncate_semicolon_case` WRITE;
/*!40000 ALTER TABLE `truncate_semicolon_case` DISABLE KEYS */;

/*!40000 ALTER TABLE `truncate_semicolon_case` ENABLE KEYS */;
UNLOCK TABLES;
