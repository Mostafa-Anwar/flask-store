from app import create_app

app = create_app()

if __name__ == '__main__':
    print("Starting app with host=0.0.0.0")  # Debugging
    # app.run(host='0.0.0.0', port=5000)
    app.run(host='0.0.0.0')