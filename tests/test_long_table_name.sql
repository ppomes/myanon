-- MySQL dump 10.13  Distrib 8.0.39, for Linux (x86_64)
--
-- Host: localhost    Database: test_long_table_name
-- ------------------------------------------------------
-- Server version	8.0.39

DROP TABLE IF EXISTS `ttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttta`;
CREATE TABLE `ttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttta` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(64) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4;

LOCK TABLES `ttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttta` WRITE;
INSERT INTO `ttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttta` VALUES (1,'Alice','alice@corp.example.org'),(2,'Bob','bob@corp.example.org');
UNLOCK TABLES;

DROP TABLE IF EXISTS `tttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttb`;
CREATE TABLE `tttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttb` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(64) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4;

LOCK TABLES `tttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttb` WRITE;
INSERT INTO `tttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttb` VALUES (1,'Alice','alice@corp.example.org'),(2,'Bob','bob@corp.example.org');
UNLOCK TABLES;

-- Dump completed on 2026-09-08 12:00:00
