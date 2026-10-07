/*M!999999\- enable the sandbox mode */ 
-- MariaDB dump 10.20-11.8.9-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: shop
-- ------------------------------------------------------
-- Server version	11.8.9-MariaDB-ubu2404

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*M!100616 SET @OLD_NOTE_VERBOSITY=@@NOTE_VERBOSITY, NOTE_VERBOSITY=0 */;

--
-- Table structure for table `customers`
--

DROP TABLE IF EXISTS `customers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `customers` (
  `id` int(11) NOT NULL,
  `name` varchar(50) DEFAULT NULL,
  `email` varchar(80) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `customers`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `customers` WRITE;
/*!40000 ALTER TABLE `customers` DISABLE KEYS */;
INSERT INTO `customers` VALUES
(1,'Customer 1','customer1@corp.fr'),
(2,'Customer 2','customer2@corp.fr'),
(3,'Customer 3','customer3@corp.fr'),
(4,'Customer 4','customer4@corp.fr'),
(5,'Customer 5','customer5@corp.fr'),
(6,'Customer 6','customer6@corp.fr'),
(7,'Customer 7','customer7@corp.fr'),
(8,'Customer 8','customer8@corp.fr'),
(9,'Customer 9','customer9@corp.fr'),
(10,'Customer 10','customer10@corp.fr'),
(11,'Customer 11','customer11@corp.fr'),
(12,'Customer 12','customer12@corp.fr'),
(13,'Customer 13','customer13@corp.fr'),
(14,'Customer 14','customer14@corp.fr'),
(15,'Customer 15','customer15@corp.fr'),
(16,'Customer 16','customer16@corp.fr'),
(17,'Customer 17','customer17@corp.fr'),
(18,'Customer 18','customer18@corp.fr'),
(19,'Customer 19','customer19@corp.fr'),
(20,'Customer 20','customer20@corp.fr'),
(21,'Customer 21','customer21@corp.fr'),
(22,'Customer 22','customer22@corp.fr'),
(23,'Customer 23','customer23@corp.fr'),
(24,'Customer 24','customer24@corp.fr'),
(25,'Customer 25','customer25@corp.fr'),
(26,'Customer 26','customer26@corp.fr'),
(27,'Customer 27','customer27@corp.fr'),
(28,'Customer 28','customer28@corp.fr'),
(29,'Customer 29','customer29@corp.fr'),
(30,'Customer 30','customer30@corp.fr'),
(31,'Customer 31','customer31@corp.fr'),
(32,'Customer 32','customer32@corp.fr'),
(33,'Customer 33','customer33@corp.fr'),
(34,'Customer 34','customer34@corp.fr'),
(35,'Customer 35','customer35@corp.fr'),
(36,'Customer 36','customer36@corp.fr'),
(37,'Customer 37','customer37@corp.fr'),
(38,'Customer 38','customer38@corp.fr'),
(39,'Customer 39','customer39@corp.fr'),
(40,'Customer 40','customer40@corp.fr'),
(41,'Customer 41','customer41@corp.fr'),
(42,'Customer 42','customer42@corp.fr'),
(43,'Customer 43','customer43@corp.fr'),
(44,'Customer 44','customer44@corp.fr'),
(45,'Customer 45','customer45@corp.fr'),
(46,'Customer 46','customer46@corp.fr'),
(47,'Customer 47','customer47@corp.fr'),
(48,'Customer 48','customer48@corp.fr'),
(49,'Customer 49','customer49@corp.fr'),
(50,'Customer 50','customer50@corp.fr'),
(51,'Customer 51','customer51@corp.fr'),
(52,'Customer 52','customer52@corp.fr'),
(53,'Customer 53','customer53@corp.fr'),
(54,'Customer 54','customer54@corp.fr'),
(55,'Customer 55','customer55@corp.fr'),
(56,'Customer 56','customer56@corp.fr'),
(57,'Customer 57','customer57@corp.fr'),
(58,'Customer 58','customer58@corp.fr'),
(59,'Customer 59','customer59@corp.fr'),
(60,'Customer 60','customer60@corp.fr'),
(61,'Customer 61','customer61@corp.fr'),
(62,'Customer 62','customer62@corp.fr'),
(63,'Customer 63','customer63@corp.fr'),
(64,'Customer 64','customer64@corp.fr'),
(65,'Customer 65','customer65@corp.fr'),
(66,'Customer 66','customer66@corp.fr'),
(67,'Customer 67','customer67@corp.fr'),
(68,'Customer 68','customer68@corp.fr'),
(69,'Customer 69','customer69@corp.fr'),
(70,'Customer 70','customer70@corp.fr'),
(71,'Customer 71','customer71@corp.fr'),
(72,'Customer 72','customer72@corp.fr'),
(73,'Customer 73','customer73@corp.fr'),
(74,'Customer 74','customer74@corp.fr'),
(75,'Customer 75','customer75@corp.fr'),
(76,'Customer 76','customer76@corp.fr'),
(77,'Customer 77','customer77@corp.fr'),
(78,'Customer 78','customer78@corp.fr'),
(79,'Customer 79','customer79@corp.fr'),
(80,'Customer 80','customer80@corp.fr'),
(81,'Customer 81','customer81@corp.fr'),
(82,'Customer 82','customer82@corp.fr'),
(83,'Customer 83','customer83@corp.fr'),
(84,'Customer 84','customer84@corp.fr'),
(85,'Customer 85','customer85@corp.fr'),
(86,'Customer 86','customer86@corp.fr'),
(87,'Customer 87','customer87@corp.fr'),
(88,'Customer 88','customer88@corp.fr'),
(89,'Customer 89','customer89@corp.fr'),
(90,'Customer 90','customer90@corp.fr'),
(91,'Customer 91','customer91@corp.fr'),
(92,'Customer 92','customer92@corp.fr'),
(93,'Customer 93','customer93@corp.fr'),
(94,'Customer 94','customer94@corp.fr'),
(95,'Customer 95','customer95@corp.fr'),
(96,'Customer 96','customer96@corp.fr'),
(97,'Customer 97','customer97@corp.fr'),
(98,'Customer 98','customer98@corp.fr'),
(99,'Customer 99','customer99@corp.fr');
INSERT INTO `customers` VALUES
(100,'Customer 100','customer100@corp.fr'),
(101,'Customer 101','customer101@corp.fr'),
(102,'Customer 102','customer102@corp.fr'),
(103,'Customer 103','customer103@corp.fr'),
(104,'Customer 104','customer104@corp.fr'),
(105,'Customer 105','customer105@corp.fr'),
(106,'Customer 106','customer106@corp.fr'),
(107,'Customer 107','customer107@corp.fr'),
(108,'Customer 108','customer108@corp.fr'),
(109,'Customer 109','customer109@corp.fr'),
(110,'Customer 110','customer110@corp.fr'),
(111,'Customer 111','customer111@corp.fr'),
(112,'Customer 112','customer112@corp.fr'),
(113,'Customer 113','customer113@corp.fr'),
(114,'Customer 114','customer114@corp.fr'),
(115,'Customer 115','customer115@corp.fr'),
(116,'Customer 116','customer116@corp.fr'),
(117,'Customer 117','customer117@corp.fr'),
(118,'Customer 118','customer118@corp.fr'),
(119,'Customer 119','customer119@corp.fr'),
(120,'Customer 120','customer120@corp.fr'),
(121,'Customer 121','customer121@corp.fr'),
(122,'Customer 122','customer122@corp.fr'),
(123,'Customer 123','customer123@corp.fr'),
(124,'Customer 124','customer124@corp.fr'),
(125,'Customer 125','customer125@corp.fr'),
(126,'Customer 126','customer126@corp.fr'),
(127,'Customer 127','customer127@corp.fr'),
(128,'Customer 128','customer128@corp.fr'),
(129,'Customer 129','customer129@corp.fr'),
(130,'Customer 130','customer130@corp.fr'),
(131,'Customer 131','customer131@corp.fr'),
(132,'Customer 132','customer132@corp.fr'),
(133,'Customer 133','customer133@corp.fr'),
(134,'Customer 134','customer134@corp.fr'),
(135,'Customer 135','customer135@corp.fr'),
(136,'Customer 136','customer136@corp.fr'),
(137,'Customer 137','customer137@corp.fr'),
(138,'Customer 138','customer138@corp.fr'),
(139,'Customer 139','customer139@corp.fr'),
(140,'Customer 140','customer140@corp.fr'),
(141,'Customer 141','customer141@corp.fr'),
(142,'Customer 142','customer142@corp.fr'),
(143,'Customer 143','customer143@corp.fr'),
(144,'Customer 144','customer144@corp.fr'),
(145,'Customer 145','customer145@corp.fr'),
(146,'Customer 146','customer146@corp.fr'),
(147,'Customer 147','customer147@corp.fr'),
(148,'Customer 148','customer148@corp.fr'),
(149,'Customer 149','customer149@corp.fr'),
(150,'Customer 150','customer150@corp.fr'),
(151,'Customer 151','customer151@corp.fr'),
(152,'Customer 152','customer152@corp.fr'),
(153,'Customer 153','customer153@corp.fr'),
(154,'Customer 154','customer154@corp.fr'),
(155,'Customer 155','customer155@corp.fr'),
(156,'Customer 156','customer156@corp.fr'),
(157,'Customer 157','customer157@corp.fr'),
(158,'Customer 158','customer158@corp.fr'),
(159,'Customer 159','customer159@corp.fr'),
(160,'Customer 160','customer160@corp.fr'),
(161,'Customer 161','customer161@corp.fr'),
(162,'Customer 162','customer162@corp.fr'),
(163,'Customer 163','customer163@corp.fr'),
(164,'Customer 164','customer164@corp.fr'),
(165,'Customer 165','customer165@corp.fr'),
(166,'Customer 166','customer166@corp.fr'),
(167,'Customer 167','customer167@corp.fr'),
(168,'Customer 168','customer168@corp.fr'),
(169,'Customer 169','customer169@corp.fr'),
(170,'Customer 170','customer170@corp.fr'),
(171,'Customer 171','customer171@corp.fr'),
(172,'Customer 172','customer172@corp.fr'),
(173,'Customer 173','customer173@corp.fr'),
(174,'Customer 174','customer174@corp.fr'),
(175,'Customer 175','customer175@corp.fr'),
(176,'Customer 176','customer176@corp.fr'),
(177,'Customer 177','customer177@corp.fr'),
(178,'Customer 178','customer178@corp.fr'),
(179,'Customer 179','customer179@corp.fr'),
(180,'Customer 180','customer180@corp.fr'),
(181,'Customer 181','customer181@corp.fr'),
(182,'Customer 182','customer182@corp.fr'),
(183,'Customer 183','customer183@corp.fr'),
(184,'Customer 184','customer184@corp.fr'),
(185,'Customer 185','customer185@corp.fr'),
(186,'Customer 186','customer186@corp.fr'),
(187,'Customer 187','customer187@corp.fr'),
(188,'Customer 188','customer188@corp.fr'),
(189,'Customer 189','customer189@corp.fr'),
(190,'Customer 190','customer190@corp.fr'),
(191,'Customer 191','customer191@corp.fr');
INSERT INTO `customers` VALUES
(192,'Customer 192','customer192@corp.fr'),
(193,'Customer 193','customer193@corp.fr'),
(194,'Customer 194','customer194@corp.fr'),
(195,'Customer 195','customer195@corp.fr'),
(196,'Customer 196','customer196@corp.fr'),
(197,'Customer 197','customer197@corp.fr'),
(198,'Customer 198','customer198@corp.fr'),
(199,'Customer 199','customer199@corp.fr'),
(200,'Customer 200','customer200@corp.fr');
/*!40000 ALTER TABLE `customers` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*M!100616 SET NOTE_VERBOSITY=@OLD_NOTE_VERBOSITY */;

-- Dump completed
