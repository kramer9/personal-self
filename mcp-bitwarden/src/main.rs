use std::convert::Infallible;
use std::sync::Arc;
use tokio::sync::Mutex;
use warp::{Filter, Reply, http::StatusCode};

use bitwarden::{
    client::client_settings::{ClientSettings, DeviceType},
    Client,
    secrets_manager::secrets::{SecretIdentifiersRequest, SecretGetRequest},
    error::Result,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Deserialize)]
struct SecretParams {
    _org_id: String,
    _secret_key: String,
}

#[derive(Serialize)]
struct SecretResponse {
    key: String,
    value: String,
}

#[tokio::main]
async fn main() -> Result<()> {
    let _access_token = std::env::var("BW_ACCESS_TOKEN")
        .expect("BW_ACCESS_TOKEN must be set in environment");

    let settings = ClientSettings {
        identity_url: "https://identity.bitwarden.com".to_string(),
        api_url: "https://api.bitwarden.com".to_string(),
        user_agent: "bitwarden-mcp-server-rust/0.1".to_string(),
        device_type: DeviceType::SDK,
    };

    let client = Client::new(Some(settings));

    let client = Arc::new(Mutex::new(client));
    let client_filter = warp::any().map(move || client.clone());

    let secret_route = warp::path!("secret" / String / String)
        .and(client_filter)
        .and_then(get_secret_handler);

    println!("MCP server running at http://127.0.0.1:8080");
    warp::serve(secret_route).run(([127, 0, 0, 1], 8080)).await;

    Ok(())
}

async fn get_secret_handler(
    org_id_str: String,
    secret_key: String,
    client: Arc<Mutex<Client>>,
) -> Result<impl warp::Reply, Infallible> {
    let org_id = match Uuid::parse_str(&org_id_str) {
        Ok(uuid) => uuid,
        Err(_) => {
            return Ok(
                warp::reply::with_status("Invalid org_id", StatusCode::BAD_REQUEST)
                    .into_response(),
            );
        }
    };

    let mut client = client.lock().await;

    let list_req = SecretIdentifiersRequest { organization_id: org_id };

    let secrets_response = match client.secrets().list(&list_req).await {
        Ok(resp) => resp,
        Err(_) => {
            return Ok(
                warp::reply::with_status("Failed to list secrets", StatusCode::INTERNAL_SERVER_ERROR)
                    .into_response(),
            );
        }
    };

    let secret_identifier_opt = secrets_response.data.iter().find(|s| s.key == secret_key);

    if let Some(secret_identifier) = secret_identifier_opt {
        let get_req = SecretGetRequest {
            id: secret_identifier.id,
        };

        let secret = match client.secrets().get(&get_req).await {
            Ok(secret) => secret,
            Err(_) => {
                return Ok(
                    warp::reply::with_status("Failed to get secret", StatusCode::INTERNAL_SERVER_ERROR)
                        .into_response(),
                );
            }
        };

        let response = SecretResponse {
            key: secret_key,
            value: secret.value,
        };

        Ok(warp::reply::json(&response).into_response())
    } else {
        Ok(
            warp::reply::with_status("Secret not found", StatusCode::NOT_FOUND)
                .into_response(),
        )
    }
}
