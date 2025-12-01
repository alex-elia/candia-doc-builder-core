# Multi-stage Dockerfile for Candia Doc Builder
# Supports both library usage and FastAPI service

# Stage 1: Builder stage
FROM python:3.11-slim as builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Stage 2: Runtime stage
FROM python:3.11-slim

WORKDIR /app

# Install runtime system dependencies
# Note: LaTeX is optional - uncomment if needed (adds ~500MB to image)
# For minimal LaTeX support, use texlive-latex-base only
RUN apt-get update && apt-get install -y --no-install-recommends \
    # LaTeX (minimal - uncomment if needed)
    # texlive-latex-base \
    # texlive-latex-extra \
    # texlive-fonts-recommended \
    # Fonts for better rendering
    fonts-liberation \
    fonts-dejavu-core \
    # Image processing libraries
    libjpeg-dev \
    zlib1g-dev \
    # Cleanup
    && rm -rf /var/lib/apt/lists/*

# Copy Python dependencies from builder
COPY --from=builder /root/.local /root/.local

# Make sure scripts in .local are usable
ENV PATH=/root/.local/bin:$PATH

# Copy application code
COPY requirements.txt .
COPY scripts/ ./scripts/
COPY examples/ ./examples/
COPY Templates/ ./Templates/
COPY images/ ./images/

# Copy app directory if it exists (for FastAPI service)
COPY app/ ./app/ 2>/dev/null || true

# Install additional FastAPI dependencies if app exists
# This allows the Dockerfile to work with or without FastAPI
RUN if [ -d "app" ] && [ -f "app/main.py" ]; then \
        pip install --no-cache-dir --user fastapi uvicorn[standard] pydantic pydantic-settings; \
    fi

# Create non-root user for security
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

USER appuser

# Expose port (default for FastAPI, can be overridden)
EXPOSE 8000

# Default command: Run FastAPI if app exists, otherwise Python shell
# Can be overridden in docker-compose or k8s deployment
CMD if [ -f "app/main.py" ]; then \
        uvicorn app.main:app --host 0.0.0.0 --port 8000; \
    else \
        python -c "print('Candia Doc Builder - Library Mode. Import modules to use.'); import sys; sys.exit(0)"; \
    fi



