<?php 

$p1 = $_GET['p1'];
$p2 = $_GET['p2'];
$p3 = $_GET['p3'];
$temp1 = str_replace("C", "", $p1);
$temp2 = str_replace("C", "", $p2);
$timestamp = mktime();
$conector = mysql_connect('mysql.geodar.com', 'terahz', 't3rah3') or die(mysql_error());
mysql_select_db('hydrareef') or die(mysql_error());


$sqlQuery = "set time_zone = '-5:00'";
$dataReturned = mysql_query($sqlQuery) or die(mysql_error());
$sqlQuery = "call addMetric(5,$temp2);";
$dataReturned = mysql_query($sqlQuery) or die(mysql_error());
$your_data = date("d-m-Y H:i:s", $timestamp) . "," . $p1 . "," . $p2 . "," . $p3. "\n";

echo "OK";

// Open the file for appending
$fp = fopen("data.txt", "a");

// Write the data to the file
fwrite($fp, $your_data);

// Close the file
fclose($fp);
?>
