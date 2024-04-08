from faker import Faker

def email():
    fake = Faker()
    return fake.email()

def firstname():
    fake = Faker()
    return fake.first_name()

def lastname():
    fake = Faker()
    return fake.last_name()

