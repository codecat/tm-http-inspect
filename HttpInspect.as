array<RequestInfo@> g_requests;
bool g_capturing;

bool g_windowVisible;

class RequestInfo
{
	int64 m_time;
	string m_method; // GET, POST, PUT

	bool m_useCache;
	string m_url;
	string m_headers;

	string m_resource; // For POST and PUT requests
	string m_filename; // For file POST requests
}

RequestInfo@ AddRequestInfo(const string &in method)
{
	auto ret = RequestInfo();
	ret.m_time = Time::Stamp;
	ret.m_method = method;
	g_requests.InsertLast(ret);
	return ret;
}

string CommandLineSafe(const string &in str)
{
	return str.Replace("\\", "\\\\").Replace("'", "'\\''");
}

void RenderInterface()
{
	if (!g_windowVisible) {
		return;
	}

	if (UI::Begin("Http Inspector", g_windowVisible)) {
		g_capturing = UI::Checkbox("Capturing", g_capturing);
		UI::SameLine();
		if (UI::Button("Clear")) {
			g_requests.RemoveRange(0, g_requests.Length);
		}

		float scale = UI::GetScale();

		if (UI::BeginTable("Requests", 4, UI::TableFlags::Resizable)) {
			UI::TableSetupColumn("Time", UI::TableColumnFlags::WidthFixed, 50 * scale);
			UI::TableSetupColumn("Method", UI::TableColumnFlags::WidthFixed, 80 * scale);
			UI::TableSetupColumn("URL", UI::TableColumnFlags::WidthStretch);
			UI::TableSetupColumn("Actions", UI::TableColumnFlags::WidthFixed, 250 * scale);
			UI::TableHeadersRow();

			for (int i = int(g_requests.Length - 1); i >= 0; i--) {
				UI::TableNextRow();

				auto request = g_requests[i];
				UI::PushID(request);

				// Time
				UI::TableSetColumnIndex(0);
				UI::Text(Time::Stamp - request.m_time + "s");

				// Method
				UI::TableSetColumnIndex(1);
				UI::Text(request.m_method);

				// URL
				UI::TableSetColumnIndex(2);
				UI::Text(request.m_url);

				// Actions
				UI::TableSetColumnIndex(3);
				if (UI::Button(Icons::Clipboard + " URL")) {
					IO::SetClipboard(request.m_url);
				}

				if (request.m_headers != "") {
					UI::SameLine();
					if (UI::Button(Icons::Clipboard + " Headers")) {
						IO::SetClipboard(request.m_headers);
					}
				}

				if (request.m_resource != "") {
					UI::SameLine();
					if (UI::Button(Icons::Clipboard + " Resource")) {
						IO::SetClipboard(request.m_resource);
					}
				}

				if (request.m_filename != "") {
					UI::SameLine();
					if (UI::Button(Icons::Clipboard + " Filename")) {
						IO::SetClipboard(request.m_filename);
					}
				}

				UI::SameLine();
				if (UI::Button(Icons::CodeFork + " Curl")) {
					string curl = "curl";
					if (request.m_method != "GET") {
						curl += " -X " + request.m_method;
					}
					if (request.m_headers != "") {
						auto lines = request.m_headers.Split("\n");
						for (uint j = 0; j < lines.Length; j++) {
							curl += " -H '" + CommandLineSafe(lines[j]) + "'";
						}
					}
					if (request.m_resource != "") {
						curl += " -d '" + CommandLineSafe(request.m_resource) + "'";
					}
					if (request.m_url.Contains("[") || request.m_url.Contains("{")) {
						curl += " -g";
					}
					curl += " '" + CommandLineSafe(request.m_url) + "'";
					IO::SetClipboard(curl);
				}

				UI::PopID();
			}

			UI::EndTable();
		}
	}
	UI::End();
}

void RenderMenu()
{
	if (UI::MenuItem("\\$9cf" + Icons::Search + "\\$z Http Inspector", "", g_windowVisible)) {
		g_windowVisible = !g_windowVisible;
	}
}

bool FuncCreateGet(CMwStack &in stack)
{
	if (!g_capturing) {
		return true;
	}

	auto request = AddRequestInfo("GET");

	int available = stack.Count() - stack.Index() - 1;
	if (available == 3) {
		request.m_url = stack.CurrentString(2);
		request.m_useCache = stack.CurrentBool(1);
		request.m_headers = stack.CurrentString(0);
	} else if (available == 2) {
		request.m_url = stack.CurrentString(1);
		request.m_useCache = stack.CurrentBool(0);
	} else if (available == 1) {
		request.m_url = stack.CurrentString(0);
	}

	return true;
}

bool FuncCreatePost(CMwStack &in stack)
{
	if (!g_capturing) {
		return true;
	}

	auto request = AddRequestInfo("POST");

	int available = stack.Count() - stack.Index() - 1;
	if (available == 3) {
		request.m_url = stack.CurrentString(2);
		request.m_resource = stack.CurrentString(1);
		request.m_headers = stack.CurrentString(0);
	} else if (available == 2) {
		request.m_url = stack.CurrentString(1);
		request.m_resource = stack.CurrentString(0);
	}

	return true;
}

bool FuncCreatePostFile(CMwStack &in stack)
{
	if (!g_capturing) {
		return true;
	}

	auto request = AddRequestInfo("POST");

	request.m_url = stack.CurrentString(2);
	request.m_filename = stack.CurrentWString(1);
	request.m_headers = stack.CurrentString(0);

	return true;
}

bool FuncCreatePut(CMwStack &in stack)
{
	if (!g_capturing) {
		return true;
	}

	auto request = AddRequestInfo("PUT");

	request.m_url = stack.CurrentString(2);
	request.m_resource = stack.CurrentString(1);
	request.m_headers = stack.CurrentString(0);

	return true;
}

void Main()
{
	Dev::InterceptProc("CNetScriptHttpManager", "CreateGet", FuncCreateGet);
	Dev::InterceptProc("CNetScriptHttpManager", "CreateGet2", FuncCreateGet);
	Dev::InterceptProc("CNetScriptHttpManager", "CreateGet3", FuncCreateGet);

	Dev::InterceptProc("CNetScriptHttpManager", "CreatePost", FuncCreatePost);
	Dev::InterceptProc("CNetScriptHttpManager", "CreatePost2", FuncCreatePost);
	Dev::InterceptProc("CNetScriptHttpManager", "CreatePostFile", FuncCreatePostFile);
	Dev::InterceptProc("CNetScriptHttpManager", "CreatePut", FuncCreatePut);

	while (true) {
		yield();
	}
}
