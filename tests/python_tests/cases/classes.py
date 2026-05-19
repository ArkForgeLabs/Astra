class Empty:
    pass

e = Empty()
print("created")

class Greeter:
    def greet(self):
        return "hello"

g = Greeter()
print(g.greet())

class Adder:
    def __init__(self, n):
        self.n = n
    def add(self, x):
        return self.n + x

a = Adder(5)
print(a.add(3))

class Base:
    def method(self):
        return 1

class Derived(Base):
    def method(self):
        return 2

d = Derived()
print(d.method())

class WithClassVar:
    val = 42

print(WithClassVar.val)
