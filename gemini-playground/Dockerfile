FROM python:3.12-alpine
RUN pip install --no-cache-dir truststore
WORKDIR /app
COPY runner.py /app/runner.py
COPY boot.py /app/boot.py
COPY run.sh /run.sh
RUN chmod a+x /run.sh
CMD [ "/run.sh" ]
