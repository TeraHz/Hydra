<?php 
require_once("JSON.php");

$conector = mysql_connect('mysql.geodar.com', 'terahz', 't3rah3') or die(mysql_error());
mysql_select_db('hydrareef') or die(mysql_error());

$sqlQuery = "select MAX(m.date) as date, m.value as value from Metrics m, Categories c where c.id = m.categoryId and c.name = '". $_GET['category']. "' AND " ;
$sqlQuery .= "m.date = (select MAX(m.date) as date from Metrics m, Categories c where c.id = m.categoryId and c.name =  '". $_GET['category']. "')";
$dataReturned = mysql_query($sqlQuery) or die(mysql_error());
$i = 0;

while($row = mysql_fetch_array($dataReturned)){

	$value{$i}{"date"}= $row['date'];
	$value{$i}{"value"}= $row['value'];
	$i++;
}


$json = new Services_JSON();
$output = $json->encode($value);
print($output);
?>

