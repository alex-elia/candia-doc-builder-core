# FastAPI Structure for Candia Doc Builder

## Project Structure

```
candia-doc-builder/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI app entry point
│   ├── config.py            # Configuration (env vars)
│   ├── dependencies.py      # Dependency injection
│   │
│   ├── routers/             # API endpoints
│   │   ├── __init__.py
│   │   ├── pptx.py          # PPTX generation endpoints
│   │   └── latex.py         # LaTeX/PDF generation endpoints
│   │
│   ├── services/            # Business logic
│   │   ├── __init__.py
│   │   ├── pptx_generator.py
│   │   └── latex_generator.py
│   │
│   ├── models/              # Pydantic models
│   │   ├── __init__.py
│   │   ├── requests.py      # Request models
│   │   └── responses.py    # Response models
│   │
│   └── utils/               # Utilities
│       ├── storage.py       # Supabase/OVH storage
│       └── templates.py    # Template loading
│
├── requirements.txt
├── Dockerfile
└── README.md
```

## Example: main.py

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import pptx, latex
from config import settings

app = FastAPI(
    title="Candia Doc Builder API",
    description="Document generation service for Elia Go",
    version="1.0.0",
    docs_url="/docs",      # Swagger UI
    redoc_url="/redoc"     # ReDoc
)

# CORS middleware (for Edge Function calls)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(pptx.router, prefix="/api/v1/pptx", tags=["PPTX"])
app.include_router(latex.router, prefix="/api/v1/latex", tags=["LaTeX"])

@app.get("/health")
async def health_check():
    """Health check endpoint for Kubernetes"""
    return {"status": "healthy", "service": "candia-doc-builder"}

@app.get("/")
async def root():
    return {
        "message": "Candia Doc Builder API",
        "docs": "/docs",
        "version": "1.0.0"
    }
```

## Example: models/requests.py

```python
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any
from enum import Enum

class ReportType(str, Enum):
    RFP_RESPONSE = "rfp_response"
    ESG_REPORT = "esg_report"
    READINESS_REPORT = "readiness_report"

class TemplateBrand(str, Enum):
    ELIAGO = "eliago"
    CUSTOM = "custom"

class ReportRequest(BaseModel):
    """Request model for document generation"""
    report_type: ReportType = Field(..., description="Type of report to generate")
    template_brand: TemplateBrand = Field(..., description="Brand/template to use")
    company_id: str = Field(..., description="Company ID for storage isolation")
    data: Dict[str, Any] = Field(..., description="Report content data")
    metadata: Optional[Dict[str, Any]] = Field(None, description="Additional metadata")
    language: str = Field("en", description="Report language")
    
    class Config:
        json_schema_extra = {
            "example": {
                "report_type": "rfp_response",
                "template_brand": "eliago",
                "company_id": "company_123",
                "data": {
                    "title": "RFP Response",
                    "sections": [...]
                },
                "language": "en"
            }
        }
```

## Example: routers/pptx.py

```python
from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from models.requests import ReportRequest
from models.responses import ReportResponse
from services.pptx_generator import PPTXGenerator
from dependencies import get_storage, get_templates
from typing import Annotated
import logging

logger = logging.getLogger(__name__)

router = APIRouter()

@router.post("/generate", response_model=ReportResponse)
async def generate_pptx(
    request: ReportRequest,
    background_tasks: BackgroundTasks,
    storage: Annotated[Storage, Depends(get_storage)],
    templates: Annotated[TemplateLoader, Depends(get_templates)]
):
    """
    Generate PowerPoint presentation (PPTX)
    
    - Validates request automatically
    - Generates PPTX using python-pptx
    - Uploads to storage
    - Returns signed URL
    """
    try:
        logger.info(f"Generating PPTX: {request.report_type} for {request.company_id}")
        
        # Initialize generator
        generator = PPTXGenerator(
            storage=storage,
            templates=templates
        )
        
        # Generate document
        pptx_file = await generator.generate(
            report_type=request.report_type,
            template_brand=request.template_brand,
            data=request.data,
            language=request.language
        )
        
        # Upload to storage
        storage_path = f"{request.company_id}/reports/{request.report_type}/{request.language}.pptx"
        file_url = await storage.upload(
            path=storage_path,
            file=pptx_file,
            content_type="application/vnd.openxmlformats-officedocument.presentationml.presentation"
        )
        
        # Background task: Update database tracking
        background_tasks.add_task(
            update_report_tracking,
            company_id=request.company_id,
            report_type=request.report_type,
            storage_path=storage_path
        )
        
        return ReportResponse(
            success=True,
            file_url=file_url,
            storage_path=storage_path,
            format="pptx"
        )
        
    except Exception as e:
        logger.error(f"PPTX generation failed: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate PPTX: {str(e)}"
        )

async def update_report_tracking(company_id: str, report_type: str, storage_path: str):
    """Background task to update report tracking in database"""
    # Call Supabase to update report_generations table
    pass
```

## Example: services/pptx_generator.py

```python
from pptx import Presentation
from pptx.util import Inches, Pt
from typing import Dict, Any
import logging

logger = logging.getLogger(__name__)

class PPTXGenerator:
    def __init__(self, storage, templates):
        self.storage = storage
        self.templates = templates
    
    async def generate(
        self,
        report_type: str,
        template_brand: str,
        data: Dict[str, Any],
        language: str
    ) -> bytes:
        """Generate PPTX file from template and data"""
        
        # Load template
        template = await self.templates.load_template(
            report_type=report_type,
            brand=template_brand
        )
        
        # Create presentation
        prs = Presentation(template)
        
        # Generate slides from data
        for section in data.get("sections", []):
            slide = prs.slides.add_slide(prs.slide_layouts[1])
            title = slide.shapes.title
            title.text = section.get("title", "")
            
            # Add content
            content = slide.placeholders[1]
            content.text = section.get("content", "")
        
        # Save to bytes
        import io
        output = io.BytesIO()
        prs.save(output)
        output.seek(0)
        
        return output.getvalue()
```

## Example: config.py

```python
from pydantic_settings import BaseSettings
from typing import List

class Settings(BaseSettings):
    """Application settings from environment variables"""
    
    # Service config
    SERVICE_NAME: str = "candia-doc-builder"
    VERSION: str = "1.0.0"
    
    # Supabase
    SUPABASE_URL: str
    SUPABASE_SERVICE_ROLE_KEY: str
    
    # OVH Storage
    OVH_STORAGE_ENDPOINT: str
    OVH_STORAGE_ACCESS_KEY: str
    OVH_STORAGE_SECRET_KEY: str
    
    # CORS
    ALLOWED_ORIGINS: List[str] = ["*"]
    
    # Kubernetes
    POD_NAME: str = ""
    NAMESPACE: str = "backend"
    
    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()
```

## Running the Service

```bash
# Install dependencies
pip install fastapi uvicorn python-pptx

# Run development server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Run production server
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
```

## Dockerfile Example

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies (for LaTeX)
RUN apt-get update && apt-get install -y \
    texlive-latex-base \
    texlive-latex-extra \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY app/ ./app/

# Run FastAPI with Uvicorn
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```











