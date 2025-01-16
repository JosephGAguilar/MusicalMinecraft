from openai import OpenAI
import os
from mss import mss
import base64

#Class that can screenshot a full screen, encode the screenshot as base64, then send it to OpenAI through OpenAPI for analysis.
class OpenAPIScreenshotter:
  def __init__(self):
    #This uses my own api key, so don't spread this around! You can replace this with your own api key if you have one.
    self.client = OpenAI(api_key="YOUR API KEY HERE")

  #screenshots screen, saves the image as fullscreen.png
  def screenshot(self):
    with mss() as sct:
      sct.shot(mon=-1, output="fullscreen.png")

  #encodes fullscreen.png as base64 for sending to OpenAI
  def encode_screenshot(self, image_path):
    with open(image_path, "rb") as image_file:
      return base64.b64encode(image_file.read()).decode('utf-8')

  #collects response from openAI based on a prompt and image
  def OpenAPI(self, prompt, image):
    response = self.client.chat.completions.create(
      model="gpt-4o-mini",
      messages=[
        {
          "role": "user",
          "content": [
            {"type": "text", "text": prompt},
            {
              "type": "image_url",
              "image_url": {
                "url": f"data:image/jpeg;base64,{image}",
              },
            },
          ],
        }
      ],
      max_tokens=300,
    )

    return(response.choices[0].message.content)


#instantiates a class of the OpenAPI Screenshotter
MinecraftMusic = OpenAPIScreenshotter()

#Sets the current directory as the directory this file is in
dir_path = os.path.dirname(os.path.realpath(__file__))

#Sceenshots screen
MinecraftMusic.screenshot()

#sets file path for image
image_path = dir_path + "/fullscreen.png"

#encodes screenshot
base64_image = MinecraftMusic.encode_screenshot(image_path)

#prompts openai for a description of the biome. Feeds response into supercollider through biome.txt file.
biome = MinecraftMusic.OpenAPI("""
  Locate the Minecraft gameplay in this screenshot and describe the biome/environment/state that the player is currently in. Use only one of the following symbols: 
  plains, forest, desert, snow, cave, swamp, ocean, home, village, danger, pause_menu, main_menu.
  Do not capitalize your answer or use any punctuation. 
  You may only use the provided symbols. 
  """, base64_image)

f = open(dir_path + "/biome.txt", "w")
f.write(biome)
f.close()
print("Checking biome...")