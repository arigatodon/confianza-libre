# Purga las imágenes de documentos de identidad 30 días después de resolverse
# la solicitud (aprobada o rechazada). No somos custodios de documentos: la
# solicitud queda con su veredicto, pero las imágenes se borran.
class PurgeIdentityDocumentsJob < ApplicationJob
  queue_as :default

  def perform
    IdentityVerification.purgeable.find_each do |verification|
      verification.documents.purge_later
    end
  end
end
