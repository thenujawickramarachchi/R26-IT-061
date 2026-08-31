import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'dashboard_screen.dart';
import 'risk_map_screen.dart';
import 'notification_screen.dart';


class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}


class _MainNavigationScreenState extends State<MainNavigationScreen> {


  int currentIndex = 0;


  final List<Widget> pages = const [

    HomeScreen(),

    DashboardScreen(),

    RiskMapScreen(),

    NotificationScreen(),

  ];



  @override
  Widget build(BuildContext context) {


    return Scaffold(


      body: pages[currentIndex],



      bottomNavigationBar: NavigationBar(


        selectedIndex: currentIndex,


        onDestinationSelected: (index){


          setState(() {

            currentIndex = index;

          });


        },



        destinations: const [


          NavigationDestination(

            icon: Icon(Icons.home_outlined),

            selectedIcon: Icon(Icons.home),

            label: "Home",

          ),



          NavigationDestination(

            icon: Icon(Icons.dashboard_outlined),

            selectedIcon: Icon(Icons.dashboard),

            label: "Dashboard",

          ),



          NavigationDestination(

            icon: Icon(Icons.map_outlined),

            selectedIcon: Icon(Icons.map),

            label: "Risk Map",

          ),



          NavigationDestination(

            icon: Icon(Icons.notifications_none),

            selectedIcon: Icon(Icons.notifications),

            label: "Alerts",

          ),



        ],


      ),


    );


  }

}