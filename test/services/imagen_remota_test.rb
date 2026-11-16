require "test_helper"

class ImagenRemotaTest < ActiveSupport::TestCase
  test "rechaza esquemas que no sean http(s)" do
    error = assert_raises(ImagenRemota::Error) { ImagenRemota.descargar("file:///etc/passwd") }
    assert_match "http", error.message
    assert_raises(ImagenRemota::Error) { ImagenRemota.descargar("ftp://x/y.png") }
    assert_raises(ImagenRemota::Error) { ImagenRemota.descargar("no es url") }
  end

  test "detecta redes privadas, loopback y link-local" do
    %w[127.0.0.1 10.1.2.3 192.168.0.5 172.16.9.9 169.254.169.254 ::1 fd00::1 0.0.0.0].each do |ip|
      assert ImagenRemota.ip_privada?(ip), "#{ip} debería ser privada"
    end
    %w[8.8.8.8 151.101.1.140 2606:4700::1111].each do |ip|
      assert_not ImagenRemota.ip_privada?(ip), "#{ip} debería ser pública"
    end
  end

  test "rechaza una URL que resuelve a una IP privada" do
    con_stub(Resolv, :getaddresses, [ "127.0.0.1" ]) do
      error = assert_raises(ImagenRemota::Error) { ImagenRemota.descargar("http://interno.local/x.png") }
      assert_match "no permitida", error.message
    end
  end

  test "rechaza si el host no resuelve" do
    con_stub(Resolv, :getaddresses, []) do
      assert_raises(ImagenRemota::Error) { ImagenRemota.descargar("https://no-existe.invalid/x.png") }
    end
  end

  # Subclase que evita la red: la respuesta HTTP la fabrica el test.
  class ImagenRemotaFalsa < ImagenRemota
    attr_accessor :respuesta, :bytes, :pedidas
    def resolver(_host) = "8.8.8.8"
    def pedir(uri, _ip)
      (@pedidas ||= []) << uri.to_s
      [ respuesta, bytes ]
    end
  end

  test "devuelve la imagen con su tipo y nombre" do
    d = ImagenRemotaFalsa.new
    d.respuesta = Net::HTTPOK.new("1.1", "200", "OK").tap { |r| r["content-type"] = "image/png; charset=binary" }
    d.bytes = "PNGDATA"

    img = d.descargar("https://misitio.cl/fotos/pan.png")
    assert_equal "image/png", img.content_type
    assert_equal "pan.png", img.filename
    assert_equal "PNGDATA", img.io.read
  end

  test "rechaza content-type que no sea imagen" do
    d = ImagenRemotaFalsa.new
    d.respuesta = Net::HTTPOK.new("1.1", "200", "OK").tap { |r| r["content-type"] = "text/html" }
    d.bytes = "<html>"
    error = assert_raises(ImagenRemota::Error) { d.descargar("https://misitio.cl/pagina") }
    assert_match "imagen", error.message
  end

  test "sigue redirecciones hasta el máximo" do
    d = ImagenRemotaFalsa.new
    d.respuesta = Net::HTTPFound.new("1.1", "302", "Found").tap { |r| r["location"] = "https://misitio.cl/otra.png" }
    d.bytes = ""
    error = assert_raises(ImagenRemota::Error) { d.descargar("https://misitio.cl/a.png") }
    assert_match "redirige", error.message
    assert_equal ImagenRemota::MAX_REDIRECTS + 1, d.pedidas.size
  end
end
