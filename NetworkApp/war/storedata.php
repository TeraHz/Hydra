<?php

include_once("db.inc.php");

$conector = mysql_connect(DB_HOST, DB_USER, DB_PASS) or die(mysql_error());
mysql_select_db(DB_NAME) or die(mysql_error());

$p1 = $_GET['p1'];
$p2 = $_GET['p2'];
$p3 = $_GET['p3'];
$p4 = $_GET['p4'];
$temp1 = str_replace("C", "", $p1);
$temp2 = str_replace("C", "", $p2);
$temp3 = str_replace("C", "", $p3);
$timestamp = mktime();



$sqlQuery = "set time_zone = '-5:00'";
$dataReturned = mysql_query($sqlQuery) or die(mysql_error());
$sqlQuery = "call addMetric(2,$temp1);";
$dataReturned = mysql_query($sqlQuery) or die(mysql_error());
$sqlQuery = "call addMetric(5,$temp2);";
$dataReturned = mysql_query($sqlQuery) or die(mysql_error());
$sqlQuery = "call addMetric(4,$temp3);";
$dataReturned = mysql_query($sqlQuery) or die(mysql_error());
$sqlQuery = "call addMetric(1,$p4);";
$dataReturned = mysql_query($sqlQuery) or die(mysql_error());
$your_data = date("d-m-Y H:i:s", $timestamp) . "," . $p1 . "," . $p2 . "," . $p3. "," . $p4 . "\n";
echo "OK";

// Open the file for appending
$fp = fopen("data.txt", "a");

// Write the data to the file
fwrite($fp, $your_data);

// Close the file
fclose($fp);
?>