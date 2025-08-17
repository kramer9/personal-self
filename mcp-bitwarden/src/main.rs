use std::convert::Infallible;
use std::process::Command;
use warp::{Filter, Reply, http::StatusCode};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Serialize)]
struct SecretResponse {
    key: String,
    value: String,
}

#[derive(Deserialize)]
struct BwsSecretResponse {
    id: String,
    #[serde(rename = "organizationId")]
    organization_id: String,
    #[serde(rename = "projectId")]
    project_id: String,
    key: String,
    value: String,
    note: String,
    #[serde(rename = "creationDate")]
    creation_date: String,
    #[serde(rename = "revisionDate")]
    revision_date: String,
}

#[derive(Deserialize)]
struct BwsSecretIdentifier {
    id: String,
    #[serde(rename = "organizationId")]
    organization_id: String,
    #[serde(rename = "projectId")]
    project_id: String,
    key: String,
    #[serde(rename = "creationDate")]
    creation_date: String,
    #[serde(rename = "revisionDate")]
    revision_date: String,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Verify BWS_ACCESS_TOKEN is set
    std::env::var("BWS_ACCESS_TOKEN")
        .expect("BWS_ACCESS_TOKEN must be set in environment");

    println!("Using bws CLI wrapper approach");

    let secret_route = warp::path!("secret" / String / String)
        .and(warp::get())
        .and_then(get_secret_handler);

    // Add health check endpoint
    let health_route = warp::path("health")
        .and(warp::get())
        .and_then(health_check);

    let routes = secret_route.or(health_route);

    println!("MCP server running at http://127.0.0.1:8080");
    println!("Endpoints:");
    println!("  GET /secret/<org_id>/<secret_key>");
    println!("  GET /health");

    warp::serve(routes).run(([127, 0, 0, 1], 8080)).await;

    Ok(())
}

async fn health_check() -> Result<impl Reply, Infallible> {
    // Test if bws command is available and working
    match Command::new("bws").arg("--version").output() {
        Ok(output) if output.status.success() => {
            Ok(warp::reply::with_status("OK - bws CLI available", StatusCode::OK))
        }
        _ => {
            Ok(warp::reply::with_status("ERROR - bws CLI not available", StatusCode::SERVICE_UNAVAILABLE))
        }
    }
}

async fn get_secret_handler(
    org_id_str: String,
    secret_key: String,
) -> Result<impl Reply, Infallible> {
    let org_id = match Uuid::parse_str(&org_id_str) {
        Ok(uuid) => uuid,
        Err(_) => {
            return Ok(
                warp::reply::with_status(
                    warp::reply::json(&serde_json::json!({
                        "error": "Invalid organization ID format"
                    })),
                    StatusCode::BAD_REQUEST,
                ).into_response()
            );
        }
    };

    println!("Attempting to find secret '{}' in org: {}", secret_key, org_id);

    // Step 1: First, we need to list all secrets without specifying project
    // The bws CLI works differently - let's try listing all secrets first
    let list_output = Command::new("bws")
        .args(&["secret", "list", "--output", "json"])
        .output();

    let list_result = match list_output {
        Ok(output) if output.status.success() => {
            String::from_utf8_lossy(&output.stdout).to_string()
        }
        Ok(output) => {
            let error_msg = String::from_utf8_lossy(&output.stderr);
            eprintln!("bws list command failed: {}", error_msg);
            return Ok(
                warp::reply::with_status(
                    warp::reply::json(&serde_json::json!({
                        "error": "Failed to list secrets via bws CLI",
                        "details": error_msg.to_string()
                    })),
                    StatusCode::INTERNAL_SERVER_ERROR,
                ).into_response()
            );
        }
        Err(e) => {
            eprintln!("Failed to execute bws command: {}", e);
            return Ok(
                warp::reply::with_status(
                    warp::reply::json(&serde_json::json!({
                        "error": "bws CLI not available",
                        "details": e.to_string()
                    })),
                    StatusCode::INTERNAL_SERVER_ERROR,
                ).into_response()
            );
        }
    };

    // Parse the JSON response from bws list - it's a direct array, not wrapped in {data: [...]}
    let secrets_list: Vec<BwsSecretIdentifier> = match serde_json::from_str(&list_result) {
        Ok(list) => list,
        Err(e) => {
            eprintln!("Failed to parse bws list output: {}", e);
            eprintln!("Raw output: {}", list_result);
            return Ok(
                warp::reply::with_status(
                    warp::reply::json(&serde_json::json!({
                        "error": "Failed to parse bws output",
                        "details": e.to_string()
                    })),
                    StatusCode::INTERNAL_SERVER_ERROR,
                ).into_response()
            );
        }
    };

    // Find the secret with matching key and organization
    let secret_identifier = secrets_list.iter().find(|s| 
        s.key == secret_key && s.organization_id == org_id.to_string()
    );

    let secret_id = match secret_identifier {
        Some(identifier) => {
            println!("Found secret '{}' with ID: {}", secret_key, identifier.id);
            &identifier.id
        }
        None => {
            println!("Secret '{}' not found in org {}. Available secrets: {:?}", 
                secret_key, 
                org_id,
                secrets_list.iter()
                    .filter(|s| s.organization_id == org_id.to_string())
                    .map(|s| &s.key)
                    .collect::<Vec<_>>()
            );
            return Ok(
                warp::reply::with_status(
                    warp::reply::json(&serde_json::json!({
                        "error": format!("Secret '{}' not found in organization", secret_key),
                        "available_secrets": secrets_list.iter()
                            .filter(|s| s.organization_id == org_id.to_string())
                            .map(|s| &s.key)
                            .collect::<Vec<_>>()
                    })),
                    StatusCode::NOT_FOUND,
                ).into_response()
            );
        }
    };

    // Step 2: Get the full secret details using the secret ID
    let get_output = Command::new("bws")
        .args(&["secret", "get", secret_id, "--output", "json"])
        .output();

    let secret_result = match get_output {
        Ok(output) if output.status.success() => {
            String::from_utf8_lossy(&output.stdout).to_string()
        }
        Ok(output) => {
            let error_msg = String::from_utf8_lossy(&output.stderr);
            eprintln!("bws get command failed: {}", error_msg);
            return Ok(
                warp::reply::with_status(
                    warp::reply::json(&serde_json::json!({
                        "error": "Failed to get secret via bws CLI",
                        "details": error_msg.to_string()
                    })),
                    StatusCode::INTERNAL_SERVER_ERROR,
                ).into_response()
            );
        }
        Err(e) => {
            eprintln!("Failed to execute bws get command: {}", e);
            return Ok(
                warp::reply::with_status(
                    warp::reply::json(&serde_json::json!({
                        "error": "bws CLI execution failed",
                        "details": e.to_string()
                    })),
                    StatusCode::INTERNAL_SERVER_ERROR,
                ).into_response()
            );
        }
    };

    // Parse the secret details
    let secret: BwsSecretResponse = match serde_json::from_str(&secret_result) {
        Ok(secret) => secret,
        Err(e) => {
            eprintln!("Failed to parse bws get output: {}", e);
            eprintln!("Raw output: {}", secret_result);
            return Ok(
                warp::reply::with_status(
                    warp::reply::json(&serde_json::json!({
                        "error": "Failed to parse secret details",
                        "details": e.to_string()
                    })),
                    StatusCode::INTERNAL_SERVER_ERROR,
                ).into_response()
            );
        }
    };

    let response = SecretResponse {
        key: secret.key,
        value: secret.value,
    };

    println!("Successfully returning secret for key: {}", secret_key);
    Ok(warp::reply::json(&response).into_response())
}