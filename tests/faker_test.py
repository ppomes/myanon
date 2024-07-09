from faker import Faker

def email(notused):
    fake = Faker()
    return fake.email()

def firstname(notused):
    fake = Faker()
    return fake.first_name()

def lastname(notused):
    fake = Faker()
    return fake.last_name()

