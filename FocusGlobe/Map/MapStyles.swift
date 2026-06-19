import Foundation

/// Calm, minimal Google Maps style JSON for Light and Dark mode.
///
/// These hide busy POIs, businesses and transit so the map stays serene and
/// the route + balloon are the focus. Used only by the Google renderer; the
/// fallback map styles itself with the route's mood gradient.
enum MapStyles {

    static let light = """
    [
      {"featureType":"poi","stylers":[{"visibility":"off"}]},
      {"featureType":"poi.park","elementType":"geometry","stylers":[{"visibility":"on"},{"color":"#dceccd"}]},
      {"featureType":"transit","stylers":[{"visibility":"off"}]},
      {"featureType":"road","elementType":"labels","stylers":[{"visibility":"off"}]},
      {"featureType":"road","elementType":"geometry","stylers":[{"color":"#f3f4f7"}]},
      {"featureType":"administrative","elementType":"labels","stylers":[{"lightness":20}]},
      {"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},
      {"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#eef1f6"}]},
      {"featureType":"water","elementType":"geometry","stylers":[{"color":"#bcd6ea"}]},
      {"featureType":"water","elementType":"labels","stylers":[{"visibility":"off"}]}
    ]
    """

    static let dark = """
    [
      {"elementType":"geometry","stylers":[{"color":"#0c1326"}]},
      {"elementType":"labels.text.fill","stylers":[{"color":"#7b87a6"}]},
      {"elementType":"labels.text.stroke","stylers":[{"color":"#070b18"}]},
      {"featureType":"poi","stylers":[{"visibility":"off"}]},
      {"featureType":"transit","stylers":[{"visibility":"off"}]},
      {"featureType":"road","elementType":"labels","stylers":[{"visibility":"off"}]},
      {"featureType":"road","elementType":"geometry","stylers":[{"color":"#141d38"}]},
      {"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},
      {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#8a96b6"}]},
      {"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#9aa6c4"}]},
      {"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#0f1730"}]},
      {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#101a36"}]},
      {"featureType":"water","elementType":"geometry","stylers":[{"color":"#070d1e"}]},
      {"featureType":"water","elementType":"labels","stylers":[{"visibility":"off"}]}
    ]
    """
}
