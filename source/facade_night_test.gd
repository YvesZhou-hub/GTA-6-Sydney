extends SceneTree
## Compiles the exact pure night functions extracted from both GLSL sources as
## CPU C++ arithmetic. This validates masks/exposure, not Metal shader rendering.
const PATHS=["res://shaders/city_facade.gdshader","res://assets/world_facade.gdshader"]
var checks:Array=[]
var failures:=0
func _initialize():call_deferred("run")
func verify(label:String,passed:bool,evidence:Dictionary={}) -> void:
	checks.append({"name":label,"passed":passed,"evidence":evidence})
	print("PASS " if passed else "FAIL ",label," ",JSON.stringify(evidence))
	if not passed:failures+=1
func functions_block(code:String) -> String:
	return code.get_slice("// NIGHT_FUNCTIONS_BEGIN",1).get_slice("// NIGHT_FUNCTIONS_END",0)
func run() -> void:
	var folder:=ProjectSettings.globalize_path("res://../reports/facade-night");DirAccess.make_dir_recursive_absolute(folder)
	var a:String=FileAccess.get_file_as_string(PATHS[0]);var b:String=FileAccess.get_file_as_string(PATHS[1])
	verify("both facade resources load as spatial shaders",load(PATHS[0]) is Shader and load(PATHS[1]) is Shader and load(PATHS[0]).get_mode()==Shader.MODE_SPATIAL and load(PATHS[1]).get_mode()==Shader.MODE_SPATIAL)
	var global_setting:Dictionary=ProjectSettings.get_setting("shader_globals/city_night_amount",{})
	verify("global city night amount is declared once with daylight default",global_setting.get("type","")=="float" and float(global_setting.get("value",-1.0))==0.0 and a.count("global uniform float city_night_amount;")==1 and b.count("global uniform float city_night_amount;")==1)
	verify("both shaders execute identical deterministic night functions",not functions_block(a).is_empty() and functions_block(a)==functions_block(b) and a.contains("EMISSION = night_radiance(") and b.contains("EMISSION = night_radiance("))
	verify("window occupancy has no clock camera or object-instance dependency",not a.contains("TIME;") and not b.contains("TIME;") and not a.contains("CAMERA_POSITION") and not b.contains("CAMERA_POSITION") and not a.contains("INSTANCE_ID") and not b.contains("INSTANCE_ID") and not functions_block(a).contains("sin("))
	verify("OSM identity survives interpolation and seed includes facade direction",a.contains("varying flat vec2 facade_identity;") and a.contains("facade_identity = UV2;") and a.contains("floor(facade_identity.x*10000.0+0.5)+face_index*10007.0"))
	verify("both shaders filter subpixel windows and suppress roof emission",a.contains("length(fwidth(grid))") and b.contains("length(fwidth(st))") and a.contains("city_night_amount)*(1.0-step(0.6,is_roof))") and b.contains("*(1.0-step(0.6,is_roof))"))
	verify("day albedo expressions retain authored close facade colours",a.contains("ALBEDO=mix(wall,glass_color.rgb*(0.82+0.18*cell.y),window);") and b.contains("mix(stone,glass,glazing),detail_fade)") and not a.contains("ALBEDO = night_") and not b.contains("ALBEDO = night_"))
	var trim:="clamp(lit_windows/"+b.get_slice("*clamp(lit_windows/",1).get_slice(")",0)+")"
	var cpp:=CPU_PREFIX+functions_block(a)+"\nfloat legacy_trim(float lit_windows){return "+trim+";}\n"+CPU_TESTS
	var cpp_path:=folder+"/night-functions.cpp";var bin_path:=folder+"/night-functions"
	FileAccess.open(cpp_path,FileAccess.WRITE).store_string(cpp)
	var output:Array=[];var compiler:int=OS.execute("/usr/bin/clang++",["-std=c++17","-O2","-Wall","-Wextra","-Werror",cpp_path,"-o",bin_path],output,true)
	FileAccess.open(folder+"/cpu-compile.log",FileAccess.WRITE).store_string("\n".join(output))
	verify("exact shader night functions compile as bounded CPU arithmetic",compiler==0,{"exit":compiler,"compiler":"/usr/bin/clang++","scope":"GLSL pure function bodies with vector/builtin C++ adapters; no GPU shader compiler"})
	if compiler==0:
		output.clear();var result:int=OS.execute(bin_path,[],output,true);var cpu_text:String="\n".join(output)
		FileAccess.open(folder+"/cpu-results.json",FileAccess.WRITE).store_string(cpu_text)
		var cpu:Variant=JSON.parse_string(cpu_text)
		verify("compiled CPU mask fixture completes and returns evidence",result==0 and cpu is Dictionary,{"exit":result})
		if cpu is Dictionary:
			for item:Dictionary in cpu.checks:verify(item.name,item.passed,item.get("evidence",{}))
	var report:={"passed":failures==0,"count":checks.size(),"failures":failures,"checks":checks,"gpu_run":false,"native_shader_compile":false,"method":"Godot headless resource loading and exact GLSL pure functions compiled as CPU C++","hashes":{}}
	for path in PATHS+["res://../source/facade_night_test.gd","res://project.godot"]:report.hashes[path]=FileAccess.get_sha256(path)
	FileAccess.open(folder+"/checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("FACADE_NIGHT_COMPLETE checks=",checks.size()," failures=",failures);quit(1 if failures else 0)

const CPU_PREFIX="""
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <string>
using uint=uint32_t;
struct vec2 { float x,y; vec2(float a,float b):x(a),y(b){} };
struct vec3 { float x,y,z; vec3(float a,float b,float c):x(a),y(b),z(c){} };
vec3 operator*(vec3 a,float b){return vec3(a.x*b,a.y*b,a.z*b);}
vec3 mix(vec3 a,vec3 b,float t){return vec3(a.x*(1-t)+b.x*t,a.y*(1-t)+b.y*t,a.z*(1-t)+b.z*t);}
float clamp(float a,float lo,float hi){return std::clamp(a,lo,hi);}
float step(float edge,float value){return value<edge?0.0f:1.0f;}
"""
const CPU_TESTS="""
int failures=0, count=0;
void check(const char* name,bool ok,const std::string& evidence="{}") {
    if(count++)std::cout<<",";
    std::cout<<"{\\"name\\":\\""<<name<<"\\",\\"passed\\":"<<(ok?"true":"false")<<",\\"evidence\\":"<<evidence<<"}";
    if(!ok)++failures;
}
float magnitude(vec3 c){return c.x+c.y+c.z;}
bool same(vec3 a,vec3 b){return a.x==b.x&&a.y==b.y&&a.z==b.z;}
bool near(vec3 a,vec3 b){return std::abs(a.x-b.x)<0.000002f&&std::abs(a.y-b.y)<0.000002f&&std::abs(a.z-b.z)<0.000002f;}
int main(){
    std::cout<<std::setprecision(9)<<"{\\"checks\\":[";
    // Independent published-output anchors detect accidental hash/mask changes.
    check("integer hash reference vectors remain fixed",night_hash(0u)==0u&&night_hash(1u)==1753845952u&&night_hash(123456789u)==2834422664u);
    bool stable=true,negative=true,range=true;int changed=0,occupied[3]={0,0,0};
    double resolved[3]={0,0,0};float highest=0.0f;
    for(int y=0;y<128;y++)for(int x=0;x<128;x++){
        vec2 cell{float(x),float(y)};
        float h=night_random(cell,7231.0f,211u);
        stable&=h==night_random(cell,7231.0f,211u);
        negative&=std::isfinite(night_random(vec2(-float(x),-float(y)),-172.0f,211u));
        range&=h>=0.0f&&h<1.0f;
        changed+=h!=night_random(cell,7232.0f,211u);
        for(int usage=0;usage<3;usage++){
            vec3 rgb=night_radiance(cell,7231.0f,float(usage),1.0f,0.4f,1.0f,1.0f);
            occupied[usage]+=magnitude(rgb)>0;
            resolved[usage]+=magnitude(rgb);
            highest=std::max(highest,std::max(rgb.x,std::max(rgb.y,rgb.z)));
        }
    }
    check("repeated occupied-window masks are bit-identical",stable);
    check("different building IDs produce different stable window masks",changed>16300,"{\\"changed_random_values\\":"+std::to_string(changed)+",\\"samples\\":16384}");
    check("signed floor and window indices remain finite and bounded",negative&&range);
    for(int usage=0;usage<3;usage++){
        float fraction=occupied[usage]/16384.0f;
        check(("occupancy density matches usage "+std::to_string(usage)).c_str(),std::abs(fraction-night_density(float(usage)))<0.03f,"{\\"fraction\\":"+std::to_string(fraction)+",\\"target\\":"+std::to_string(night_density(float(usage)))+"}");
    }
    check("residential occupancy exceeds office and other occupancy",occupied[1]>occupied[0]&&occupied[0]>occupied[2]);
    check("night emission preserves glass exposure and legacy trim cannot amplify it",highest>0.42f&&highest<=0.495601f&&legacy_trim(10.0f)==1.0f&&legacy_trim(.05f)==1.0f&&legacy_trim(0.0f)==0.0f&&legacy_trim(-1.0f)==0.0f,"{\\"maximum_component\\":"+std::to_string(highest)+"}");
    bool zero=true,panes=true,linear=true,clamped=true,tints=true;
    int warm=0,cool=0;
    for(int x=0;x<512;x++){
        vec2 cell(float(x),17.0f);
        vec3 full=night_radiance(cell,7231,0,1,.4,1,1);
        zero&=magnitude(night_radiance(cell,7231,0,1,.4,1,0))==0;
        panes&=magnitude(night_radiance(cell,7231,0,0,.4,1,1))==0;
        linear&=near(night_radiance(cell,7231,0,1,.4,1,.5),full*.5f);
        clamped&=same(night_radiance(cell,7231,0,1,.4,1,10),full)&&magnitude(night_radiance(cell,7231,0,1,.4,1,-10))==0;
        if(magnitude(full)>0){warm+=full.x>full.z;cool+=full.z>full.x;tints&=full.x>0&&full.y>0&&full.z>0;}
    }
    check("daylight has exactly zero added window emission",zero);
    check("resolved walls and mullions cannot emit between panes",panes);
    check("twilight is continuous proportional exposure with a fixed mask",linear);
    check("global night amount clamps safely outside unit interval",clamped);
    check("occupied windows include stable warm and cool temperatures",tints&&warm>20&&cool>20,"{\\"warm\\":"+std::to_string(warm)+",\\"cool\\":"+std::to_string(cool)+"}");
    bool averaged=true,area=true,blend=true;
    for(int usage=0;usage<3;usage++){
        vec3 far=night_radiance(vec2(0,0),0,float(usage),1,.4,0,1);
        averaged&=same(far,night_radiance(vec2(191,399),9999,float(usage),0,.4,0,1));
        area&=magnitude(night_radiance(vec2(0,0),0,float(usage),1,0,0,1))==0;
        vec3 exact=night_radiance(vec2(42,17),7231,float(usage),1,.4,1,1);
        blend&=near(night_radiance(vec2(42,17),7231,float(usage),1,.4,.5,1),mix(far,exact,.5));
        double expected=resolved[usage]*0.4/16384.0;
        check(("subpixel average preserves sampled emitted energy usage "+std::to_string(usage)).c_str(),std::abs(magnitude(far)-expected)/expected<.05,"{\\"filtered\\":"+std::to_string(magnitude(far))+",\\"sample_mean\\":"+std::to_string(expected)+"}");
    }
    check("fully filtered windows contain no seed floor or window noise",averaged);
    check("subpixel exposure respects actual total pane area",area);
    check("derivative transition blends resolved and averaged emission continuously",blend);
    std::cout<<"],\\"failures\\":"<<failures<<"}\\n";
    return failures?1:0;
}
"""
