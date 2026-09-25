#include <Arduino.h>
#include <U8g2lib.h>
#include <Arduino_GFX_Library.h>

#define TFT_MOSI 7
#define TFT_SCLK 6
#define TFT_CS 10
#define TFT_DC 2
#define TFT_RST -1
#define TFT_BL 3
#define SCREEN_W 240
#define SCREEN_H 240

#define BLACK 0x0000
#define WHITE 0xFFFF
#define BLUE 0x001F
#define GREEN 0x07E0
#define ORANGE 0xFD20
#define RED 0xF800

#define FONT_MEDIUM u8g2_font_helvB12_tf
#define FONT_LARGE u8g2_font_logisoso42_tf
#define FONT_STELLAR u8g2_font_logisoso42_tf

Arduino_DataBus *bus = new Arduino_ESP32SPI(TFT_DC,TFT_CS,TFT_SCLK,TFT_MOSI,NOT_A_PIN,FSPI);
Arduino_GFX *tft = new Arduino_GC9A01(bus,TFT_RST,0,true);
Arduino_Canvas *canvas = new Arduino_Canvas(SCREEN_W,SCREEN_H,tft,0,0);

float cpuTemp=0.0f, gpuTemp=0.0f;
String bufferSerial="";
bool recebeuDados=false;
unsigned long ultimoPacote=0, ultimaAtualizacao=0, inicioSplash=0;
const unsigned long TIMEOUT_DADOS=5000, INTERVALO=1000, DURACAO_SPLASH=4200;

struct Estrela { int16_t x,y; uint8_t brilho,tamanho; };
const Estrela estrelas[]={
{18,25,120,1},{35,16,210,1},{52,34,160,1},{72,18,255,1},{92,31,120,1},{112,14,190,1},
{136,29,230,1},{157,17,150,1},{180,35,255,1},{205,21,175,1},{220,43,220,1},{14,59,210,1},
{31,74,130,1},{55,61,245,1},{79,78,170,1},{99,57,210,1},{126,72,145,1},{149,58,250,1},
{173,75,185,1},{197,59,220,1},{225,79,150,1},{18,101,170,1},{42,92,235,1},{66,108,140,1},
{91,94,255,1},{117,106,185,1},{142,91,225,1},{168,110,150,1},{194,96,250,1},{220,111,190,1},
{13,132,235,1},{37,146,160,1},{61,129,210,1},{84,150,255,1},{108,135,150,1},{132,148,230,1},
{158,132,180,1},{183,151,245,1},{209,134,150,1},{228,151,220,1},{20,177,160,1},{43,165,250,1},
{67,184,190,1},{92,169,225,1},{116,188,145,1},{142,171,255,1},{166,187,170,1},{192,173,230,1},
{218,188,180,1},{17,211,225,1},{39,224,145,1},{64,207,255,1},{88,222,180,1},{112,207,235,1},
{139,224,155,1},{162,207,245,1},{188,221,175,1},{213,205,230,1}};
const int TOTAL_ESTRELAS=sizeof(estrelas)/sizeof(estrelas[0]);

uint16_t rgb565(uint8_t r,uint8_t g,uint8_t b){return ((r&0xF8)<<8)|((g&0xFC)<<3)|(b>>3);}
uint16_t misturarCor(uint16_t a,uint16_t b,float f){
 f=constrain(f,0.0f,1.0f);
 uint8_t ar=((a>>11)&31)<<3, ag=((a>>5)&63)<<2, ab=(a&31)<<3;
 uint8_t br=((b>>11)&31)<<3, bg=((b>>5)&63)<<2, bb=(b&31)<<3;
 return rgb565(ar+(br-ar)*f,ag+(bg-ag)*f,ab+(bb-ab)*f);
}
uint16_t corTemperatura(float t){
 if(t<=30)return BLUE;
 if(t<45)return misturarCor(BLUE,GREEN,(t-30)/15.0f);
 if(t<60)return misturarCor(GREEN,ORANGE,(t-45)/15.0f);
 if(t<75)return misturarCor(ORANGE,RED,(t-60)/15.0f);
 return RED;
}
void textoCentro(const char* s,const uint8_t* f,int cx,int y,uint16_t cor){
 canvas->setFont(f); int16_t x1,y1; uint16_t w,h; canvas->getTextBounds(s,0,0,&x1,&y1,&w,&h);
 canvas->setTextColor(cor); canvas->setCursor(cx-(int)w/2,y); canvas->print(s);
}
void textoContorno(const char* s,const uint8_t* f,int cx,int y,uint16_t cor){
 canvas->setFont(f); int16_t x1,y1; uint16_t w,h; canvas->getTextBounds(s,0,0,&x1,&y1,&w,&h);
 int x=cx-(int)w/2; canvas->setTextColor(BLACK);
 for(int dx=-2;dx<=2;dx++)for(int dy=-2;dy<=2;dy++)if(dx||dy){canvas->setCursor(x+dx,y+dy);canvas->print(s);}
 canvas->setTextColor(cor);canvas->setCursor(x,y);canvas->print(s);
}
void processarPacote(String p){
 p.trim(); if(!p.startsWith("CPU:"))return; int g=p.indexOf(";GPU:"); if(g<0)return;
 String cs=p.substring(4,g), gs=p.substring(g+5); cs.trim();gs.trim(); if(!cs.length()||!gs.length())return;
 char *ec=nullptr,*eg=nullptr; float c=strtof(cs.c_str(),&ec),v=strtof(gs.c_str(),&eg);
 if(ec==cs.c_str()||eg==gs.c_str()||c<0||c>120||v<0||v>120)return;
 cpuTemp=c;gpuTemp=v;ultimoPacote=millis();bool primeiro=!recebeuDados;recebeuDados=true;
 if(primeiro){ultimaAtualizacao=0;}
}
void processarSerial(){
 while(Serial.available()){
  char c=(char)Serial.read(); if(c=='\r')continue;
  if(c=='\n'){bufferSerial.trim();if(bufferSerial.length())processarPacote(bufferSerial);bufferSerial="";continue;}
  if(bufferSerial.length()<100)bufferSerial+=c;else bufferSerial="";
 }
}
void borda(float t){
 uint16_t cor=corTemperatura(t);
 for(int r=116;r>=78;r--){float f=(float)(r-78)/38.0f;canvas->drawCircle(120,120,r,misturarCor(BLACK,cor,f*f));}
}
void separador(){
 canvas->drawFastHLine(70,118,100,rgb565(18,18,18));canvas->drawFastHLine(66,119,108,rgb565(42,42,42));
 canvas->drawFastHLine(62,120,116,rgb565(100,100,100));canvas->drawFastHLine(62,121,116,rgb565(65,65,65));
 canvas->drawFastHLine(66,122,108,rgb565(35,35,35));canvas->drawFastHLine(70,123,100,rgb565(15,15,15));
}
void temperatura(const char* titulo,float temp,int centroY){
 int ly=strcmp(titulo,"CPU")==0?54:145;textoCentro(titulo,FONT_MEDIUM,120,ly,WHITE);
 char val[12];snprintf(val,sizeof(val),"%.0f",temp);canvas->setFont(FONT_LARGE);
 int16_t x1,y1;uint16_t w,h;canvas->getTextBounds(val,0,0,&x1,&y1,&w,&h);
 int x=120-(int)w/2, base=centroY+(int)h/2-4;canvas->setTextColor(WHITE);canvas->setCursor(x,base);canvas->print(val);
 canvas->fillCircle(x+w+7,base-h+9,3,WHITE);
}
void interface(){
 canvas->fillScreen(BLACK);borda(cpuTemp>gpuTemp?cpuTemp:gpuTemp);temperatura("CPU",cpuTemp,101);separador();temperatura("GPU",gpuTemp,191);canvas->flush();
}
void estrelasFrame(unsigned long tempo){
 for(int i=0;i<TOTAL_ESTRELAS;i++){auto &e=estrelas[i];uint8_t p=((tempo/90)+(i*17))%100;
 float in=p<50?0.35f+(p/50.0f)*0.65f:1.0f-((p-50)/50.0f)*0.65f;uint8_t b=e.brilho*in;
 canvas->drawPixel(e.x,e.y,rgb565(b,b,b));}
}
void cometa(float p){
 float m=p<.08f?0.0f:(p>.78f?1.0f:(p-.08f)/.70f);m=m*m*(3-2*m);
 float x=-45+m*335,y=220-m*190;const float dx=-.82f,dy=.57f;
 for(int i=70;i>=1;i--){float q=(float)i/70,px=x+dx*i*1.25f,py=y+dy*i*1.25f,b=(1-q)*(1-q);
  uint16_t c=rgb565(80+175*b,100+155*b,255);int r=i<14?3:(i<32?2:1);canvas->fillCircle(px,py,r,c);}
 canvas->fillCircle(x,y,10,rgb565(35,55,110));canvas->fillCircle(x,y,7,rgb565(80,125,220));canvas->fillCircle(x,y,4,WHITE);
}
void splash(unsigned long tempo){
 canvas->fillScreen(BLACK);float p=(float)tempo/DURACAO_SPLASH;estrelasFrame(tempo);cometa(p);
 float in=1.0f;if(p<.18f)in=p/.18f;if(p>.90f)in=(1-p)/.10f;in=constrain(in,0.0f,1.0f);uint8_t b=255*in;
 textoContorno("STELLAR",FONT_STELLAR,120,137,rgb565(b,b,b));canvas->flush();
}
void setup(){
 Serial.begin(115200);pinMode(TFT_BL,OUTPUT);digitalWrite(TFT_BL,HIGH);tft->begin();tft->setRotation(3);canvas->begin();
 canvas->fillScreen(BLACK);canvas->flush();bufferSerial.reserve(128);inicioSplash=millis();
 Serial.println("STELLAR aguardando dados do sistema...");
}
void loop(){
 processarSerial();
 if(recebeuDados && millis()-ultimoPacote>TIMEOUT_DADOS){recebeuDados=false;inicioSplash=millis();}
 if(!recebeuDados){splash((millis()-inicioSplash)%DURACAO_SPLASH);delay(16);return;}
 if(millis()-ultimaAtualizacao>=INTERVALO){ultimaAtualizacao=millis();interface();}
 delay(5);
}
