use actix_web::{get, http::header::AUTHORIZATION, web, App, HttpRequest, HttpResponse, HttpServer, Responder};
use bitwarden::{
    auth::login::AccessTokenLoginRequest,
    client::{client_settings::{ClientSettings, DeviceType}, Client},
    client::traits::{ClientAuthExt, ClientSecretsExt},
    error::Result as BWResult,
    secrets_manager::secrets::SecretIdentifiersRequest,
};
use serde::Serialize;
use std::env;
use tokio_retry::strategy::ExponentialBackoff;
use tokio_retry::Retry;
use tracing::{error, info};
use uuid::Uuid;

#[derive(Serialize)]
struct SecretResponse {
    message: String,
    secret: String,
}

#[get("/secret/{name}")]
async fn get_secret(req: HttpRequest, path: web::Path<String>) -> impl Responder {
    let name = path.into_inner();

    let expected_api_key = env::var("MCP_API_KEY").unwrap_or_else(|_| "changeme".to_string());
    let auth_header = req.headers().get(AUTHORIZATION).and_then(|v| v.to_str().ok());
    if auth_header != Some(&format!("Bearer {}", expected_api_key)) {
        error!("Unauthorized access attempt");
        return HttpResponse::Unauthorized().body("Unauthorized");
    }

    info!("Authorized request for secret '{}'", &name);

    let bw_token = match env::var("BITWARDEN_ACCESS_TOKEN") {
        Ok(t) => t,
        Err(_) => {
            error!("BITWARDEN_ACCESS_TOKEN env var not set");
            return HttpResponse::InternalServerError().body("Bitwarden token missing");
        }
    };

    let settings = ClientSettings {
        identity_url: "https://identity.bitwarden.com".to_string(),
        api_url: "https://api.bitwarden.com".to_string(),
        user_agent: "MCP-Bitwarden-Server-Rust".to_string(),
        device_type: DeviceType::SDK,
    };

    let mut client = Client::new(Some(settings));

    let login_req = AccessTokenLoginRequest {
        access_token: bw_token,
        state_file: None,
    };

    if let Err(e) = client.auth().login_access_token(&login_req).await {
        error!("Bitwarden client auth failed: {:?}", e);
        return HttpResponse::InternalServerError().body("Bitwarden authentication failed");
    }

    let org_id = Some(Uuid::nil());

    let req = SecretIdentifiersRequest {
        organization_id: org_id.unwrap(),
    };

    let retry_strategy = ExponentialBackoff::from_millis(50).take(3);

    let name_clone = name.clone();

    let secret_result = Retry::spawn(retry_strategy, || async {
        let secrets_resp = client.secrets().list(&req).await?;
        let secret = secrets_resp.data.iter()
            .find(|s| s.key == name_clone)
            .ok_or_else(|| bitwarden::error::Error::MissingFields)?;
        Ok::<_, bitwarden::error::Error>(secret.key.clone())
    }).await;

    match secret_result {
        Ok(secret_val) => HttpResponse::Ok().json(SecretResponse {
            message: format!("Secret fetched for '{}'", &name),
            secret: secret_val,
        }),
        Err(e) => {
            error!("Failed to fetch secret '{}': {:?}", &name, e);
            HttpResponse::InternalServerError().body("Failed to fetch secret")
        }
    }
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    tracing_subscriber::fmt().init();

    let port: u16 = env::var("PORT").ok().and_then(|s| s.parse().ok()).unwrap_or(3000);
    info!("Starting MCP-Bitwarden server on port {}", port);

    HttpServer::new(|| App::new().service(get_secret))
        .bind(("0.0.0.0", port))?
        .run()
        .await
}
