from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    database_url: str = "postgresql+psycopg://mentoria:mentoria@db:5432/mentoria"
    jwt_secret: str = "dev-secret"
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 10080
    openai_api_key: str | None = None
    openai_model: str = "gpt-5.6-luna"
    openai_transcription_model: str = "whisper-1"
    enable_dev_tools: bool = False
    ai_enabled: bool = True
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

settings = Settings()
