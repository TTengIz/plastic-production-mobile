<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET");
header("Access-Control-Allow-Headers: Content-Type");

include_once '../config.php';

$database = new Database();
$db = $database->getConnection();

$query = "SELECT r.*, u.login, u.full_name 
          FROM rates r 
          LEFT JOIN users u ON r.user_id = u.id 
          ORDER BY r.effective_from DESC";

$stmt = $db->prepare($query);
$stmt->execute();

$rates = [];
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    $rates[] = $row;
}

echo json_encode([
    "success" => true,
    "rates" => $rates
]);
?>
