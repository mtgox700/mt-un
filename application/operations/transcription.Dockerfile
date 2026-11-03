# Image du moteur de transcription isolé (R30). Construire puis épingler par empreinte :
#   docker build -f operations/transcription.Dockerfile -t uniion-transcription operations
#   export UNIION_TRANSCRIPTION_IMAGE=$(docker image inspect --format '{{.Id}}' uniion-transcription)
# Le modèle n'est pas dans l'image : il est monté en lecture seule au lancement.
FROM python:3.12-slim
COPY requirements-transcription.lock /tmp/requirements.lock
RUN pip install --no-cache-dir -r /tmp/requirements.lock && rm /tmp/requirements.lock
USER 65532:65532
