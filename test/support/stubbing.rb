# Minitest 6 no trae `stub`. Este helper hace el swap temporal de un método
# de clase (el mismo patrón que usan los tests de TerritoryResolver) y lo
# restaura al salir, pase lo que pase.
#
#   con_stub(ImagenRemota, :descargar, imagen) { ... }          # valor fijo
#   con_stub(Resolv, :getaddresses, ->(_h) { [ "127.0.0.1" ] }) { ... }  # callable
module Stubbing
  def con_stub(objeto, metodo, valor)
    original = objeto.method(metodo)
    objeto.define_singleton_method(metodo) do |*args, **kwargs, &block|
      valor.respond_to?(:call) ? valor.call(*args, **kwargs, &block) : valor
    end
    yield
  ensure
    objeto.define_singleton_method(metodo, original)
  end
end
