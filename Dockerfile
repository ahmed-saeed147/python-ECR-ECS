FROM python:3
WORKDIR /app
copy . /app
RUN pip install --no-cache-dir -r requirements.txt
EXPOSE 8080
CMD [ "python", "app.py" ]