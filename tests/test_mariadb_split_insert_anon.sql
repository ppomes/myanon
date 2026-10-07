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
(1,'ctfaanrj','kpzrzsulwy@example.com'),
(2,'bshtiyne','ojzwnhmeto@example.com'),
(3,'xunwbtfr','mmtxqqedzr@example.com'),
(4,'enojusgw','enzqiorkym@example.com'),
(5,'kuxqhswr','gdvsngoytn@example.com'),
(6,'lkpikxak','nbyxzqcwzp@example.com'),
(7,'fdpcsbgy','lvnsydgjfr@example.com'),
(8,'kktlbvol','ihmcolerio@example.com'),
(9,'etghiilu','cgyiltewsp@example.com'),
(10,'zgupfvpq','xpriiefawy@example.com'),
(11,'yoobjpnu','fysllzxbjl@example.com'),
(12,'ckaerafq','mmkgoeergj@example.com'),
(13,'jtfzstbq','awkucvnszt@example.com'),
(14,'ihyiyrnh','mbawkxtkow@example.com'),
(15,'ptvkwubt','hssfkvsccd@example.com'),
(16,'zyctuqhc','pomzexyfpy@example.com'),
(17,'cwfaglui','kizjhbmtic@example.com'),
(18,'ecupdccw','rtckonfhvt@example.com'),
(19,'clvqzwis','fxsfvtsawl@example.com'),
(20,'lbkcmjqz','bpptmuwmyp@example.com'),
(21,'tzrfvcch','dvgqhgzlap@example.com'),
(22,'mrokuecj','yoyfyknude@example.com'),
(23,'pfdgfbik','pwxjvcwxgp@example.com'),
(24,'kdbcyluk','gwfqtphqlk@example.com'),
(25,'hlzaqmxe','ggzyvydadk@example.com'),
(26,'ubhgirll','imloibssqf@example.com'),
(27,'dslqeplo','wgrbtmjisa@example.com'),
(28,'fryzpikj','qecsbjhivz@example.com'),
(29,'dxpspubi','txmpyikesp@example.com'),
(30,'zkcvogcu','nhfwkqnfvs@example.com'),
(31,'dttivghu','icrmekrkim@example.com'),
(32,'rfmgqset','uitkjcpvoc@example.com'),
(33,'lffmlhsg','rkppparbar@example.com'),
(34,'dcezikft','kkdpdvptho@example.com'),
(35,'fqzbpoqs','eyklmxwddj@example.com'),
(36,'mjehioyj','ucdxkdpqmk@example.com'),
(37,'jsdjjbvr','upykiveakf@example.com'),
(38,'ktvcjjvv','hlfvlqjbud@example.com'),
(39,'twwugncc','nlngsreggg@example.com'),
(40,'cmvlzjom','esmnpizzcf@example.com'),
(41,'uqmhyrax','xftvbclmqq@example.com'),
(42,'movjntgv','mrulltokvc@example.com'),
(43,'qauvlxbo','ussqfzlbyc@example.com'),
(44,'szbdtlqn','mmacejjnhv@example.com'),
(45,'zfgpksht','tefgjdaqyl@example.com'),
(46,'vxnknfzn','sgbgbeoouc@example.com'),
(47,'znnyxurg','wpwkangbst@example.com'),
(48,'zspilgdt','cezjporvpd@example.com'),
(49,'dguarctt','gvvnstcqff@example.com'),
(50,'dsklfape','jvcnvoeexi@example.com'),
(51,'wixrpygg','lmbkjwfbqy@example.com'),
(52,'imydsece','ssfccxqjst@example.com'),
(53,'wrjzknvu','arsuighlsf@example.com'),
(54,'fktewbja','qdvbmtowzw@example.com'),
(55,'cqowzjzo','muwscybwbm@example.com'),
(56,'gpanolkf','dgkgimqrto@example.com'),
(57,'stkwbmmy','cxhkaaabjn@example.com'),
(58,'immlktsk','sbzjrkgmjp@example.com'),
(59,'hlucwbfj','fvvfvtxvti@example.com'),
(60,'cdirhaqu','ivuxohjmgk@example.com'),
(61,'xddondvk','fybbpypjep@example.com'),
(62,'brxhjren','argmsolgyx@example.com'),
(63,'tkcxdgsy','plvqoogsau@example.com'),
(64,'kwxebeuw','ujjxfulldk@example.com'),
(65,'qqumfdns','zwxgaipcoz@example.com'),
(66,'alrplyow','mmmergrrhn@example.com'),
(67,'pfklpwnf','kfiktqqocc@example.com'),
(68,'pbqlnfdv','fuzdjhyvzz@example.com'),
(69,'qwlrbyzt','wysgunompr@example.com'),
(70,'xphhxzwv','pbquzvyznv@example.com'),
(71,'ersamusr','nmrpqtleka@example.com'),
(72,'prgpkghc','vnrfzsgygf@example.com'),
(73,'hqomfftp','yntdofmira@example.com'),
(74,'ablgajjq','somuhoevkl@example.com'),
(75,'wcftlwrw','khqqufgnib@example.com'),
(76,'ebveolhc','uitayhdmzi@example.com'),
(77,'qmahdlbo','bzdwbffnky@example.com'),
(78,'pwkqjstc','ctldhghaey@example.com'),
(79,'ymnbvcnb','mhwrgkmsgv@example.com'),
(80,'bfmiuiiz','puwqfnkkbd@example.com'),
(81,'pnzgaqbh','rhpwequtqr@example.com'),
(82,'iuxvccwv','pnbghogpba@example.com'),
(83,'ugafojzm','ubgezxwiah@example.com'),
(84,'nxgzqyvd','oypvtljgxs@example.com'),
(85,'onvjrppg','mrmeafvmra@example.com'),
(86,'qtwbibul','mieiftgdtp@example.com'),
(87,'iraybcsu','mvusbbktvu@example.com'),
(88,'odlilpvd','ybrquhelip@example.com'),
(89,'wlgxbqlc','yaeaycnqng@example.com'),
(90,'tzwsaekm','xsjblqyctq@example.com'),
(91,'ckqskysm','clvdmxmpke@example.com'),
(92,'tebbjnqt','qbretsxmka@example.com'),
(93,'liniaeab','rrmndkjomt@example.com'),
(94,'tjznudrj','nsveejizzj@example.com'),
(95,'dshvdxqd','zbochkytlk@example.com'),
(96,'jedvjggw','hksxjhbtoo@example.com'),
(97,'shdoanuk','umdzkhyrek@example.com'),
(98,'rpgczccz','ppsuxappnu@example.com'),
(99,'ghlbrppr','lbxviygrbf@example.com');
INSERT INTO `customers` VALUES
(100,'slogbtiz','jsjmszfxwa@example.com'),
(101,'mbwphtij','sshvfqlwfc@example.com'),
(102,'jsalaiqk','skyvenvdga@example.com'),
(103,'fcdsqlsd','mysyuhqjqb@example.com'),
(104,'rmrrtwgy','dsnvqiupmk@example.com'),
(105,'oqiykdgq','zdphubekvn@example.com'),
(106,'rwezjwds','jlbsfucrri@example.com'),
(107,'agmgteaj','daapartsde@example.com'),
(108,'wkkyztbz','rnodbsxtva@example.com'),
(109,'yrgjnjvg','zoofymamjs@example.com'),
(110,'buxkdygl','decyhavhgq@example.com'),
(111,'nysyyhzd','dmxnebuqbg@example.com'),
(112,'kfwrsorr','stkcwpqczs@example.com'),
(113,'rsswjprv','jzohdvooeo@example.com'),
(114,'ooeczrji','uqnfisxcbh@example.com'),
(115,'xeeremau','llxjqjgjln@example.com'),
(116,'fhogjlda','laupdplwnd@example.com'),
(117,'ipysilsc','pbvvqmsqpq@example.com'),
(118,'xubcpdqo','fkzmfustgk@example.com'),
(119,'wrclodwy','hiqtfbcnnb@example.com'),
(120,'nkkavmmi','ukhiszkvdm@example.com'),
(121,'iieoqpla','khilwgbnbv@example.com'),
(122,'qkoihzmn','fkpelfsxmv@example.com'),
(123,'nreuwwlh','lnnftfzddy@example.com'),
(124,'cschwtgu','fjlixhqdxh@example.com'),
(125,'ukvzzbep','kekevmenia@example.com'),
(126,'aejgxiqt','fukiggxcmc@example.com'),
(127,'pttakpha','qdwgolcrjl@example.com'),
(128,'lbabyuiv','yajmdeahzc@example.com'),
(129,'rfxpimbe','ukmjfryadj@example.com'),
(130,'qszmktmo','ubemsyjalj@example.com'),
(131,'qcehczek','aoqeekhdul@example.com'),
(132,'nkgkxxap','tuvcvrriek@example.com'),
(133,'rqgvdkuq','iakwicpjiy@example.com'),
(134,'fnwfpjno','ezgydfvdig@example.com'),
(135,'uaizbukh','zbiqupflqt@example.com'),
(136,'lggjlhye','gzdvbjhfgl@example.com'),
(137,'rkdxxwem','tsrnybinxk@example.com'),
(138,'mepnsrnd','zltboewipy@example.com'),
(139,'nwxjjffn','haambtmczk@example.com'),
(140,'ercgadod','umwneznzno@example.com'),
(141,'bxsjlhhy','ruuhelswwz@example.com'),
(142,'hgnqieft','oamigixwbu@example.com'),
(143,'hqeusdsd','hqqtmkqdai@example.com'),
(144,'vvrzlqar','fcpmqqsnlk@example.com'),
(145,'jfdsldki','evemvfkshm@example.com'),
(146,'odzwgapw','svwqtgwoom@example.com'),
(147,'fgpdarmi','nskicuidpe@example.com'),
(148,'ieavqbzf','jcjtfbcbij@example.com'),
(149,'frrdxocr','vquqgkyyyh@example.com'),
(150,'dxnfmziq','sqmbfgugfi@example.com'),
(151,'tpfroaxi','oaburqhxpv@example.com'),
(152,'tmautguu','qaddmsulsn@example.com'),
(153,'ovznmvji','uaroechggf@example.com'),
(154,'ohcatljh','lfvnitpcfj@example.com'),
(155,'rlrvbxqx','pjuktzciun@example.com'),
(156,'uekktgjq','tqkdyxmxcm@example.com'),
(157,'bdwpykgg','haoifjsbjw@example.com'),
(158,'plbxjola','qllnlywhji@example.com'),
(159,'hhorfhag','ozlkaungua@example.com'),
(160,'bguvyngm','onvsdzfaza@example.com'),
(161,'nzdjdcyp','ibuwfsuwva@example.com'),
(162,'oetjtecm','lxejmajxeg@example.com'),
(163,'sjdknest','zsijuepsdn@example.com'),
(164,'dtjbmmwk','cbptjccnaw@example.com'),
(165,'vzoxsqxx','yrsuswqsbs@example.com'),
(166,'bkihulcu','lhntzycpgt@example.com'),
(167,'veqzatnj','rexddgyjjj@example.com'),
(168,'rjngudqa','oojfoxanoc@example.com'),
(169,'fybvghxd','lcrsjyudxn@example.com'),
(170,'wawompsl','evudprenbv@example.com'),
(171,'euuetuzl','jxpatdzfyy@example.com'),
(172,'enpkzshx','zyuhmdngre@example.com'),
(173,'mnmixifc','svceuyavax@example.com'),
(174,'synlmqov','cwvcytiarq@example.com'),
(175,'yjxothfr','uhhfbaghna@example.com'),
(176,'alhsaoby','ivtbsijnlc@example.com'),
(177,'nivlqqit','yrlnqvsnya@example.com'),
(178,'tkqywpum','vmkubjtwlr@example.com'),
(179,'lqlnsmwo','zqayvdtemt@example.com'),
(180,'uysegkjk','efsepsiqsp@example.com'),
(181,'idltvyrd','nkshmedngm@example.com'),
(182,'dvyiimsa','mmblkxpmth@example.com'),
(183,'hmfusqjh','blshjifgjf@example.com'),
(184,'wvhzcchc','wlmpxyqxfo@example.com'),
(185,'ipynoswv','mrrmropsmc@example.com'),
(186,'ptatstxb','uhkxjhyepm@example.com'),
(187,'xepvhxfn','szbotchqss@example.com'),
(188,'wyizbhbw','zxoptslchz@example.com'),
(189,'hkcnhzes','lgzmhqeomp@example.com'),
(190,'afhyapja','maqnjyxjib@example.com'),
(191,'xfstwofb','doagjmqhlv@example.com');
INSERT INTO `customers` VALUES
(192,'aaumnkvg','yuwhikjhnz@example.com'),
(193,'fkgwqzbw','fosniujssx@example.com'),
(194,'piplovao','mmbvwwuqtu@example.com'),
(195,'mlumjxme','iqvilbnlzl@example.com'),
(196,'lqjzzupo','uakljqfhed@example.com'),
(197,'ppkkgktl','cxkrbidkbc@example.com'),
(198,'fprxvktp','wyukqymrbt@example.com'),
(199,'qcdzrdhj','drvgfshwqx@example.com'),
(200,'cjqgqjoc','lxiwffnmhp@example.com');
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
