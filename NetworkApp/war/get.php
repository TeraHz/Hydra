<?php 

require_once("JSON.php");
include_once("db.inc.php");
$conector = mysql_connect(DB_HOST, DB_USER, DB_PASS) or die(mysql_error());
mysql_select_db(DB_NAME) or die(mysql_error());


$sqlQuery = "select m.date, m.value, c.name, c.description from Metrics m, Categories c where c.id = m.categoryId and c.name = '". $_GET['category']. "'";
$dataReturned = mysql_query($sqlQuery) or die(mysql_error());
$i = 0;

while($row = mysql_fetch_array($dataReturned)){

	$value{$i}{"date"}= $row['date'];
	$value{$i}{"value"}= $row['value'];
	$value{$i}{"category"}= $row['name'];
	$value{$i}{"description"}= $row['description'];
	$i++;
}


$json = new Services_JSON();
$output = $json->encode($value);
print($output);
?>

