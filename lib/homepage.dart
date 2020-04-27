import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' hide LocationAccuracy;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


// assign properties of actual visible widget
class HomePage extends StatefulWidget {
  HomePage({Key key, this.title}) : super(key: key);
  final String title;
  @override
  HomePageState createState() => HomePageState();
}

// this should override whats defined in flutter framework (addon)
class HomePageState extends State<HomePage> {
  // first we define our variables
  var data;
  StreamSubscription _locationSubscription;
  Location _locationTracker = Location();
  Marker marker;
  Circle circle;
  GoogleMapController _controller;
  String searchAddr;
  BitmapDescriptor pinLocationIcon;
  Iterable markers = [];

  // function that updates the position of the icon and the circle
  void updateMarker(LocationData newLocalData) {
    LatLng latlng = LatLng(newLocalData.latitude, newLocalData.longitude);
    // getMarker;
    this.setState(() {
      marker = Marker(
          markerId: MarkerId('home'),
          position: latlng,
          draggable: false,
          zIndex: 2,
          flat: true,
          anchor: Offset(0.5, 0.5));
      circle = Circle(
          circleId: CircleId('home'),
          radius: newLocalData.accuracy,
          zIndex: 1,
          strokeColor: Colors.blue,
          center: latlng,
          fillColor: Colors.blue.withAlpha(70));
    });
  }

  @override
  void initState() {
    super.initState();
    getData();

    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(size: Size(128, 128)), 'assets/train.png')
        .then((onValue) {
          setState(() {
      pinLocationIcon = onValue;
    });
  });
  }

	
  getData() async {
    try {
      var uname = 'locofinder_plus';
      var pword = 'FindYourLoco!007';
      var authn = 'Basic ' + base64Encode(utf8.encode('$uname:$pword'));

      var data = {
        'search':
        "| inputlookup kvstore_loco_current_info | where class=\"193\" | table timestamp class type locono locono_long locono_locasi locono_isi latitude longitude azimuth speed mileage",
        'output_mode': 'json',
      };

      var response = await http.post(
          'https://webui-rsi-iat.iot.comp.db.de:8089/services/search/jobs/export',
          headers: {'Authorization': authn},
          body: data);

      final int statusCode = response.statusCode;

      if (statusCode == 201 || statusCode == 200) {
        String result = response.body
            .replaceAll('"', '\"')
            .replaceAll('"mileage":"1"}}', '"mileage":"1"}};');

        var result1 = result.split(';');

        int count1 = result1.length - 1;

        List results = [];
        for (var i = 0; i <= count1; i++) {
          if (result1[i].contains('preview')) {
            var json1 = json.decode(result1[i]);
            results.add(json1['result']);
          }
        }

        Iterable _markers = Iterable.generate(60, (index) {
          Map result = results[index];
          var location_lat = num.parse(result["latitude"]);
          var location_long = num.parse(result["longitude"]);
          var time_catched = result["timestamp"];
          var Number_loco = result["locono_long"];
          var Type_loco = result["type"];
          LatLng latLngMarker = LatLng(location_lat,location_long);

          return Marker(markerId: MarkerId("marker$index"),position: latLngMarker, icon: pinLocationIcon, infoWindow: InfoWindow(title: Number_loco, snippet: 'Last Update' + time_catched));
        });

        setState(() {
          markers = _markers;
        });
      } else {
        throw Exception('Error');
      }
    } catch(e) {
      print(e.toString());
    }
  }

  _onCameraMove(CameraPosition position) {
    if (_locationSubscription != null) {
      // if it is not already cleaned
      _locationSubscription.cancel(); // get rid of location
    }
  }

  // function to get current position
  void getCurrentLocation() async {
    try {
      // wait for bytes transformation from marker
      var location = await _locationTracker.getLocation();

      updateMarker(
        location,
      );

      if (_locationSubscription != null) {
        _locationSubscription.cancel();
      }

      _locationSubscription =
          _locationTracker.onLocationChanged().listen((newLocalData) {
        if (_controller != null) {
          _controller
              .animateCamera(CameraUpdate.newCameraPosition(new CameraPosition(
            // bearing: 192.8334901395799,
            target: LatLng(newLocalData.latitude, newLocalData.longitude),
            tilt: 0,
            zoom: 16.00,
          ))); // zoom in, when my location selected
          updateMarker(newLocalData);
        }
      });
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        debugPrint('Permission Denied');
      }
    }
  }

  // clean assignments (trigger when needed)
  @override
  void dispose() {
    if (_locationSubscription != null) {
      // if it is not already cleaned
      _locationSubscription.cancel(); // get rid of location
    }
    super.dispose();
  }

  void searchandNavigate() {
    if (_locationSubscription != null) {
      // if it is not already cleaned
      _locationSubscription.cancel(); // get rid of location
    }

    if (searchAddr == '310') {
      _controller
          .animateCamera(CameraUpdate.newCameraPosition(new CameraPosition(
        // bearing: 192.8334901395799,
        target: LatLng(
          51.872799,
          4.44772,
        ),
        tilt: 0,
        zoom: 13.00,
      )));
    } else {
      Geolocator().placemarkFromAddress(searchAddr).then((result) {
        _controller
            .animateCamera(CameraUpdate.newCameraPosition(new CameraPosition(
          // bearing: 192.8334901395799,
          target: LatLng(
            result[0].position.latitude,
            result[0].position.longitude,
          ),
          tilt: 0,
          zoom: 13.00,
        )));
        // print('test');
      });
    }
  }

  // start writing the actual widgets
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        // body has two widgets
        children: <Widget>[
          // Widget 1: MAP
          _buildGoogleMaps(context),

          // Widget 2: SEARCH BOX
          Positioned(
            top: 40.0,
            right: 15.0,
            left: 15.0,
            child: Container(
              height: 50.0,
              width: double.infinity,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  color: Colors.white),
              child: TextField(
                decoration: InputDecoration(
                    hintText: 'Suche Loknummer oder Ort',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.only(left: 15.0, top: 15.0),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.search),
                      onPressed: searchandNavigate,
                      iconSize: 30.0,
                    )),
                onSubmitted: (String str) {
                  searchandNavigate();
                },
                // listen to Input and show input
                onChanged: (val) {
                  setState(() {
                    searchAddr = val;
                  });
                },
              ),
            ),
          ),
        ],
      ),
      // Widget location
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 50.0),
        child: FloatingActionButton(
            child: Icon(Icons.location_searching),
            onPressed: () {
              getCurrentLocation();
            }),
      ),
    );
  }

  Widget _buildGoogleMaps(BuildContext context) {
    return GoogleMap(
      markers: Set.from(
          markers,
        ),
      mapType: MapType.normal,
      initialCameraPosition: CameraPosition(
        target: LatLng(50.0562606, 8.5925399),
        zoom: 14.4746,
      ),
      myLocationEnabled: true,
      zoomGesturesEnabled: true,
      compassEnabled: true,
      myLocationButtonEnabled: false,
      onCameraMove: _onCameraMove,
      // markers: Set.of((marker != null) ? [marker] : []),
      // circles: Set.of((circle != null) ? [circle] : []),
      onMapCreated: (GoogleMapController controller) {
        _controller = controller;
                  });
                }
}
