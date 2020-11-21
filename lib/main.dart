import 'package:flutter/material.dart';
import './Pages/home_screen.dart';

void main()=> runApp(new MyApp());
class MyApp extends StatelessWidget{
  @override
  Widget build(BuildContext context){
    return new MaterialApp(
      home: new MyHomePage(),
      theme: new ThemeData(
        primarySwatch: Colors.blue
      ),
    );
  }
}