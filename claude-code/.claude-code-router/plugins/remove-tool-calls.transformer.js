module.exports = class RemoveToolCallsTransformer {
  name = "remove-tool-calls";

  async transformResponseOut(response) {
    const contentType = response.headers.get("Content-Type");
    const regex = /```tool_calls\n[\s\S]*?\n```\n?/g;

    if (contentType?.includes("application/json")) {
      const originalResponse = response.clone();
      
      try {
        const jsonResponse = await originalResponse.json();
        
        if (jsonResponse?.choices?.[0]?.message?.content) {
          jsonResponse.choices[0].message.content = 
            jsonResponse.choices[0].message.content.replace(regex, "");
        }

        return new Response(JSON.stringify(jsonResponse), {
          status: response.status,
          statusText: response.statusText,
          headers: response.headers,
        });
      } catch (error) {
        return response;
      }
    } 
    else if (contentType?.includes("text/event-stream")) {
      if (!response.body) {
        return response;
      }

      const decoder = new TextDecoder();
      const encoder = new TextEncoder();
      
      const stream = new ReadableStream({
        async start(controller) {
          const reader = response.body.getReader();
          let incomingBuffer = ""; 
          let searchBuffer = ""; 
          let isFiltering = false; 

          const startMarker = "```tool_calls";
          const endMarker = "```";

          try {
            while (true) {
              const { done, value } = await reader.read();
              const isFinalChunk = done;

              if (value) {
                incomingBuffer += decoder.decode(value, { stream: true });
              }

              const lines = incomingBuffer.split('\n');
              
              incomingBuffer = isFinalChunk ? '' : (lines.pop() || '');

              for (const line of lines) {
                if (line.trim() === "data: [DONE]") {
                    if (searchBuffer && !isFiltering) {
                        const chunk = { choices: [{ delta: { content: searchBuffer } }] };
                        const outLine = `data: ${JSON.stringify(chunk)}\n\n`;
                        controller.enqueue(encoder.encode(outLine));
                        searchBuffer = ""; 
                    }
                    
                    controller.enqueue(encoder.encode(line + '\n'));
                    continue;
                }

                if (!line.trim() || !line.startsWith("data: ")) {
                    controller.enqueue(encoder.encode(line + '\n'));
                    continue;
                }

                const data = JSON.parse(line.slice(6));
                const deltaContent = data.choices?.[0]?.delta?.content;

                if (deltaContent) {
                    searchBuffer += deltaContent;
                } else {
                    if (searchBuffer && !isFiltering) {
                        const chunk = { choices: [{ delta: { content: searchBuffer } }] };
                        const outLine = `data: ${JSON.stringify(chunk)}\n\n`;
                        controller.enqueue(encoder.encode(outLine));
                        searchBuffer = ""; 
                    }
                    
                    controller.enqueue(encoder.encode(line + '\n'));
                    continue;
                }

                let keepProcessing = true;
                while (keepProcessing) {
                    keepProcessing = false; 

                    if (!isFiltering) {
                        const markerPos = searchBuffer.indexOf(startMarker);
                        if (markerPos !== -1) {
                            const contentToSend = searchBuffer.substring(0, markerPos);
                            if (contentToSend) {
                                const chunk = { choices: [{ delta: { content: contentToSend } }] };
                                const outLine = `data: ${JSON.stringify(chunk)}\n\n`;
                                controller.enqueue(encoder.encode(outLine));
                            }
                            searchBuffer = searchBuffer.substring(markerPos + startMarker.length);
                            isFiltering = true;
                            keepProcessing = true; 
                        }
                    }

                    if (isFiltering) {
                        const markerPos = searchBuffer.indexOf(endMarker);
                        if (markerPos !== -1) {
                            searchBuffer = searchBuffer.substring(markerPos + endMarker.length);
                            isFiltering = false;
                            keepProcessing = true; 
                        } else {
                            searchBuffer = "";
                        }
                    }
                }

                if (!isFiltering && searchBuffer.length > 0) {
                    const potentialMarkerOverlap = startMarker.length - 1;
                    const contentToSend = searchBuffer.slice(0, -potentialMarkerOverlap);
                    searchBuffer = searchBuffer.slice(-potentialMarkerOverlap);

                    if (contentToSend) {
                        const chunk = { choices: [{ delta: { content: contentToSend } }] };
                        const outLine = `data: ${JSON.stringify(chunk)}\n\n`;
                        controller.enqueue(encoder.encode(outLine));
                    }
                }
              }

              if (isFinalChunk) {
                if (searchBuffer && !isFiltering) {
                    const chunk = { choices: [{ delta: { content: searchBuffer } }] };
                    const line = `data: ${JSON.stringify(chunk)}\n\n`;
                    controller.enqueue(encoder.encode(line));
                }
                break; 
              }
            }
          } catch (error) {
            controller.error(error);
          } finally {
            controller.close();
          }
        },
      });

      return new Response(stream, {
        status: response.status,
        statusText: response.statusText,
        headers: response.headers,
      });
    }

    return response;
  }
};
