<?php
declare(strict_types=1);

// Sonde publique : renvoie toujours {"status":"ok"} sans authentification, c'est ce que
// consomme la supervision. La version deployee n'est ajoutee que sur presentation de
// l'en-tete X-Health-Token correspondant a HEALTH_TOKEN : la connaitre revient, combine a un
// changelog public, a publier les correctifs manquants sur l'instance.
// hash_equals compare en temps constant ; un == laisserait fuir le jeton par le temps de
// reponse. Jeton non defini = version jamais exposee (fermeture par defaut).
// Convention de parc, voir docs/ci-versions-health.md dans bzhzion/admin.

$payload = ['status' => 'ok'];

$attendu = getenv('HEALTH_TOKEN') ?: '';
$fourni  = $_SERVER['HTTP_X_HEALTH_TOKEN'] ?? '';
if ($attendu !== '' && $fourni !== '' && hash_equals($attendu, $fourni)) {
    $payload['version'] = getenv('APP_VERSION') ?: 'dev';
}

http_response_code(200);
header('Content-Type: application/json');
echo json_encode($payload);
