import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFA500), // Orange color
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [

            const SizedBox(height: 9.0), // Add spacing between containers


              Container(
                height: 70,
                width: double.infinity,
                margin: const EdgeInsets.only(left: 16.0, right: 16.0),
                color: const Color.fromARGB(255, 209, 207, 203), // Orange color
              ),

            const SizedBox(height: 9.0), // Add spacing between containers

              Container(
                height: 70,
                width: double.infinity,
                margin: const EdgeInsets.only(left: 16.0, right: 16.0),
                color: const Color.fromARGB(255, 209, 207, 203), // Orange color

              ),

            const SizedBox(height: 9.0), // Add spacing between containers


              Container(
                height: 70,
                width: double.infinity,
                margin: const EdgeInsets.only(left: 16.0, right: 16.0),
                color: const Color.fromARGB(255, 209, 207, 203), // Orange color

              ),

            const SizedBox(height: 9.0), // Add spacing between containers


              Container(
                height: 70,
                width: double.infinity,
                margin: const EdgeInsets.only(left: 16.0, right: 16.0),
                color: const Color.fromARGB(255, 209, 207, 203), // Orange color

              ),

            const SizedBox(height: 9.0), // Add spacing between containers

              Container(
                height: 70,
                width: double.infinity,
                margin: const EdgeInsets.only(left: 16.0, right: 16.0),
                color: const Color.fromARGB(255, 209, 207, 203), // Orange color

              ),

              Container(
                height: 200,
                width: double.infinity,
                margin: const EdgeInsets.only(left: 16.0, right: 16.0),
                color: const Color.fromARGB(255, 255, 255, 255), // Orange color

              ),

            const SizedBox(height: 130.0), // Add spacing between containers

              Container(
                height: 70,
                width: double.infinity,
                margin: const EdgeInsets.only(left: 16.0, right: 16.0),
                color: const Color.fromARGB(255, 134, 132, 130),
              ),

            ],
          ),
        ),

        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: const Color(0xFFFFA500), // Orange color
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        )

      ),
    );
  }
}
