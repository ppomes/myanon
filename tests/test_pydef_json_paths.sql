-- MySQL dump 10.13  Distrib 8.0.39, for Linux (x86_64)
--
-- Host: localhost    Database: test_pydef_json_paths
-- ------------------------------------------------------

DROP TABLE IF EXISTS `docs`;
CREATE TABLE `docs` (
  `id` int NOT NULL,
  `data` json DEFAULT NULL,
  `list` json DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

LOCK TABLES `docs` WRITE;
INSERT INTO `docs` VALUES (1,'{\"name\": \"José Müller\", \"meta\": {\"city\": \"Zürich\"}, \"tags\": [\"café\", \"naïve\", \"ok\"], \"items\": [{\"k\": \"clé\"}, {\"k\": \"x2\"}], \"note\": \"日本語 ✓ \\\"quoted\\\"\"}','[\"été\", \"hiver\"]'),(2,'{\"name\": \"Zoë\", \"meta\": {\"city\": \"Kraków\"}, \"tags\": [], \"items\": [], \"note\": \"ñ\"}','[]'),(3,NULL,NULL);
UNLOCK TABLES;

-- Dump completed on 2026-09-24 12:00:00
