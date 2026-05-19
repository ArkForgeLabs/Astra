class Root:
    def __init__(self):
        self.tag = "root"
    def ident(self):
        return self.tag

class A(Root):
    def __init__(self):
        super().__init__()
        self.tag = "A"

class B(Root):
    def __init__(self):
        super().__init__()
        self.tag = "B"

class C(Root):
    def __init__(self):
        super().__init__()
    def method(self):
        return super().ident()

a = A()
print(a.ident())

b = B()
print(b.ident())

c = C()
c.tag = "custom"
print(c.method())
