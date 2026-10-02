import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
class GreenButton extends StatelessWidget{
 final String label; final VoidCallback? onTap; final bool outline;
 const GreenButton({super.key,required this.label,this.onTap,this.outline=false});
 @override Widget build(BuildContext c)=>SizedBox(width:double.infinity,height:50,child:ElevatedButton(
   onPressed:onTap,
   style:ElevatedButton.styleFrom(
    backgroundColor:outline?Colors.transparent:AppTheme.green,
    foregroundColor:outline?AppTheme.green:Colors.black,
    side:outline?const BorderSide(color:AppTheme.green):null,
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))
   ),child:Text(label,style:const TextStyle(fontWeight:FontWeight.w800))));
}
