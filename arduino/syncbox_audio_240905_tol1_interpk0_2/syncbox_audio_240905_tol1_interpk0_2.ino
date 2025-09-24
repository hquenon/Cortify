/*  ---------------------
 *  boite synchro audio --> PC via USB ou port parallele
 *  ---------------------
 *  
 *  - entree audio sur pin 2
 *  - sortie visualisation LED sur pin 4
 * 
 *  Aller dans Outils/Sélection du Port et du type de carte: une Uno
 *  
 *  Les deux fonctions setup et loop sont obligatoires
 *  
 *  - setup : vue une seule fois au démarrage du microcontroleur
 *  - loop : la séquence est rejouée à l'infinie
 *    pour arrêter un arduino --> le débrancher 
 *    
 *  déclaration de fonctions :
 *  
 *  void func_name(){...} ==> commence par void car ne retourne rien 
 *  
 *  pour retourner un entier par exemple:
 *  int func_name(){...}
 *  
 * == crex-230316 - T Legou & C Zielinski
 */

//==== global variables

// pin interruption qui reçoit le signal de l'entrée audio (channel 2)
int pin_audio = 2;

// n° de pin led rouge qui s'allume à chaque trigger
int pin_del = 4;

// durée allumage LED en ms
int dur_del = 150;
// start LED time
long unsigned int start_del = 0;
// indication if the DEL is light up
int del_up = 1;

// minimal delay between 2 peaks (to avoid false detection)
long unsigned int prev_stop_peak = 0;
int min_interpeak_dur = 0;

// pins du port parallele pour envoi d'un code trigger
int pin_para_1 = 6;
int pin_para_2 = 7;
int pin_para_3 = 8;
int pin_para_4 = 9;
int pin_para_5 = 10;
int pin_para_6 = 11;
int pin_para_7 = 12;
int pin_para_8 = 13;

// minimum expected trigger durations in ms
int dur_trig_1 = 2;
int dur_trig_2 = 5;
int dur_trig_3 = 8;
int dur_trig_4 = 75;
int dur_trig_5 = 100;
int dur_trig_6 = 125;
int dur_trig_7 = 150;
int dur_trig_8 = 175;
// tolerance to detect peak with a +/- tol ms duration
unsigned long tol = 1;

unsigned long dur_peak;

// associated trigger codes to be send
// from 200 to 206
// (1°) 200: 1 1 0 0  1 0 0 0 (HIGH: pin_8, pin_7, pin_4)
// (2°) 201: 1 1 0 0  1 0 0 1 (HIGH: pin_8, pin_7, pin_4, pin_1)
// (3°) 202: 1 1 0 0  1 0 1 0 (HIGH: pin_8, pin_7, pin_4, pin_2)
// (4°) 203: 1 1 0 0  1 0 1 1 (HIGH: pin_8, pin_7, pin_4, pin_2, pin_1)
// (5°) 204: 1 1 0 0  1 1 0 0 (HIGH: pin_8, pin_7, pin_4, pin_3)
// (6°) 205: 1 1 0 0  1 1 0 1 (HIGH: pin_8, pin_7, pin_4, pin_3, pin_1)
// (7°) 206: 1 1 0 0  1 1 1 0 (HIGH: pin_8, pin_7, pin_4, pin_3, pin_2)
// (8°) 207: 1 1 0 0  1 1 1 1 (HIGH: pin_8, pin_7, pin_4, pin_3, pin_2, pin_1)

// flag pour savoir si l'evenement a été vue ou non
// volatile : dit au compilateur de mettre la variable dans la RAM et pas dans le registre
// utile car quand ça part en interruption, pas le temps d'aller traiter la variable dans la RAM
// c'est ici une directive directement au compilateur 
volatile int init_peak = 0;
volatile int start_peak = 0;
volatile int stop_peak = 0;
long unsigned int start_time = 0;
long unsigned int stop_time = 0;

//--------
//-- setup: exécutée une fois au démarrage de la carte arduino
//--------
void setup() {
  
  //== Input/output definition
  
  //-- LED
  pinMode(pin_del, OUTPUT);
  
  //-- pin connected to the parallel port
  for (int ipin=pin_para_1; ipin<=pin_para_8; ipin++){
    pinMode(ipin, OUTPUT);
    digitalWrite(ipin, LOW);
  }

  //-- AUDIO IN from jack input
  pinMode(pin_audio, INPUT);

  //-- attach an event listener to the AUDIO IN pin
  // attachInterrupt(where_pin, function_to_execute, event_type)
  // event_type can be:
  // RISING (when a state change at pin_audio from 0 to 1)
  // FALLING (from 1 to 0)
  // CHANGE (from 0 to 1 OR from 1 to 0)
  attachInterrupt(digitalPinToInterrupt(pin_audio), detectEvent, CHANGE);

  //== Start check-up
  // la LED reste allumée en permanence
  // quand il y a un trigger, elle s'éteint
  digitalWrite(pin_del, HIGH);
  
  // envoi d'info dans le moniteur série
  // 9600: vitesse à laquelle on veut communiquer en BAUD 
  // Serial.begin(9600);
}

//-------
//-- loop: exécutée en boucle, toutes les micro/ms
//-------
void loop() {
  
  // if a peak has been detected: start the timer to compute 
  // the peak duration
  if (start_peak==1){
    start_time = millis();
    start_peak = 0;
  }
  // !! trigger code is send at the falling front
  if (stop_peak==1){
    // peak duration
    stop_time = millis();
    dur_peak = stop_time - start_time; 
    // Serial.println("ok-peak"); 
    // Serial.println(dur_peak);

    // send the trigger only if the current peak appears after a certain
    // amount of time from the previous peak
    //if (stop_time-prev_stop_peak >= min_interpeak_dur){  
      find_trigger_code(dur_peak);
      prev_stop_peak = stop_time;
   // }
    // re-initialize peak detection spies and times
    init_peak = 0; 
    stop_peak = 0;
    start_time = 0;
    stop_time = 0;
  }
  
  // stop DEL if dur_del is reached
  if ((del_up==0) && (millis()-start_del>=dur_del)){
    digitalWrite(pin_del, HIGH);
    del_up = 1;
  } 
}

//-----
//-- handle the event detection
//-----
void detectEvent(){ 
  //== if RISING front event: digitalRead(pin_audio) goes from 0 to 1
  if ((start_peak==0) && (digitalRead(pin_audio)==1)){
    start_peak = 1;
    init_peak = 1;
    
  //== if FALLING front event
  } else if ((init_peak==1) && (digitalRead(pin_audio)==0)){
    stop_peak = 1;
  }
}
//------
//-- find the associated trigger code depending on the peak duration
//-- send it to the parallel port
//------
void find_trigger_code(unsigned long dur_pk){
  if (dur_pk > dur_trig_8+5){
    return;
  }
  if (dur_pk >= dur_trig_8-tol){
    send_trigger(8);
  }
  else if ((dur_pk >= dur_trig_7-tol) && (dur_pk <= dur_trig_7+tol)){
    send_trigger(7);
  }
  else if ((dur_pk >= dur_trig_6-tol) && (dur_pk <= dur_trig_6+tol)){
    send_trigger(6);
  }
  else if ((dur_pk >= dur_trig_5-tol) && (dur_pk <= dur_trig_5+tol)){
    send_trigger(5);
  }
  else if ((dur_pk >= dur_trig_4-tol) && (dur_pk <= dur_trig_4+tol)){
    send_trigger(4);
  }
  else if ((dur_pk >= dur_trig_3-tol) && (dur_pk <= dur_trig_3+tol)){
    send_trigger(3);
  }
  else if ((dur_pk >= dur_trig_2-tol) && (dur_pk <= dur_trig_2+tol)){
    send_trigger(2);
  }
  else if ((dur_pk >= dur_trig_1-tol) && (dur_pk <= dur_trig_1+tol)){
    send_trigger(1);
  }
}

//----
//-- send trigger to parallel port
//----
// associated trigger codes to be send
// from 200 to 206
void send_trigger(int code){

  // Serial.print("trig: ");
  // Serial.println(code);
  
  if (code==1){
    // 200: 1 1 0 0  1 0 0 0
    digitalWrite(pin_para_8, HIGH);
    digitalWrite(pin_para_7, HIGH);
    digitalWrite(pin_para_6, LOW);
    digitalWrite(pin_para_5, LOW);
    digitalWrite(pin_para_4, HIGH);
    digitalWrite(pin_para_3, LOW);
    digitalWrite(pin_para_2, LOW);
    digitalWrite(pin_para_1, LOW);
  } else if (code==2){
    // 201: 1 1 0 0  1 0 0 1
    digitalWrite(pin_para_8, HIGH);
    digitalWrite(pin_para_7, HIGH);
    digitalWrite(pin_para_6, LOW);
    digitalWrite(pin_para_5, LOW);
    digitalWrite(pin_para_4, HIGH);
    digitalWrite(pin_para_3, LOW);
    digitalWrite(pin_para_2, LOW); 
    digitalWrite(pin_para_1, HIGH);   
  } else if (code==3){
    // 202: 1 1 0 0  1 0 1 0
    digitalWrite(pin_para_8, HIGH);
    digitalWrite(pin_para_7, HIGH);
    digitalWrite(pin_para_6, LOW);
    digitalWrite(pin_para_5, LOW);
    digitalWrite(pin_para_4, HIGH); 
    digitalWrite(pin_para_3, LOW);
    digitalWrite(pin_para_2, HIGH);
    digitalWrite(pin_para_1, LOW);
  } else if (code==4){
    // 203: 1 1 0 0  1 0 1 1
    digitalWrite(pin_para_8, HIGH);
    digitalWrite(pin_para_7, HIGH);
    digitalWrite(pin_para_6, LOW);
    digitalWrite(pin_para_5, LOW);     
    digitalWrite(pin_para_4, HIGH);
    digitalWrite(pin_para_3, LOW);
    digitalWrite(pin_para_2, HIGH);
    digitalWrite(pin_para_1, HIGH);
  } else if (code==5){
    // 204: 1 1 0 0  1 1 0 0
    digitalWrite(pin_para_8, HIGH);
    digitalWrite(pin_para_7, HIGH);
    digitalWrite(pin_para_6, LOW);
    digitalWrite(pin_para_5, LOW);
    digitalWrite(pin_para_4, HIGH); 
    digitalWrite(pin_para_3, HIGH);
    digitalWrite(pin_para_2, LOW);
    digitalWrite(pin_para_1, LOW);
  } else if (code==6){
    // 205: 1 1 0 0  1 1 0 1
    digitalWrite(pin_para_8, HIGH);
    digitalWrite(pin_para_7, HIGH);
    digitalWrite(pin_para_6, LOW);
    digitalWrite(pin_para_5, LOW);
    digitalWrite(pin_para_4, HIGH); 
    digitalWrite(pin_para_3, HIGH);
    digitalWrite(pin_para_2, LOW);
    digitalWrite(pin_para_1, HIGH);
  } else if (code==7){
    // 206: 1 1 0 0  1 1 1 0
    digitalWrite(pin_para_8, HIGH);
    digitalWrite(pin_para_7, HIGH);
    digitalWrite(pin_para_6, LOW);
    digitalWrite(pin_para_5, LOW);
    digitalWrite(pin_para_4, HIGH); 
    digitalWrite(pin_para_3, HIGH);
    digitalWrite(pin_para_2, HIGH);
    digitalWrite(pin_para_1, LOW);
  } else if (code==8){
    // 207: 1 1 0 0  1 1 1 1
    digitalWrite(pin_para_8, HIGH);
    digitalWrite(pin_para_7, HIGH);
    digitalWrite(pin_para_6, LOW);
    digitalWrite(pin_para_5, LOW);
    digitalWrite(pin_para_4, HIGH); 
    digitalWrite(pin_para_3, HIGH);
    digitalWrite(pin_para_2, HIGH);
    digitalWrite(pin_para_1, HIGH);
  }
  // see the LED signal
  digitalWrite(pin_del, LOW);
  start_del = millis();
  del_up = 0;
  
  // add a small time before stopping the trigger signal (10 ms)
  delay(10);
  for (int ipin=pin_para_1; ipin<=pin_para_8; ipin++){
    digitalWrite(ipin, LOW);
  }

}
